-- Tinytest suite for dconf module (init.lua)
--
-- This suite mocks ward modules used by dconf:
--   * ward.process (cmd)
--   * ward.env     (is_in_path)
--   * ward.fs      (is_exists, is_executable)

return function(tinytest)
	local t = tinytest.new({ name = "dconf" })

	local MODULE_CANDIDATES = { "wardlib.app.dconf" }

	local preload_orig = {
		["ward.process"] = package.preload["ward.process"],
		["ward.env"] = package.preload["ward.env"],
		["ward.fs"] = package.preload["ward.fs"],
	}

	local loaded_orig = {
		["ward.process"] = package.loaded["ward.process"],
		["ward.env"] = package.loaded["ward.env"],
		["ward.fs"] = package.loaded["ward.fs"],
	}

	for _, name in ipairs(MODULE_CANDIDATES) do
		loaded_orig[name] = package.loaded[name]
	end

	local calls = {
		cmd = {},
		is_in_path = {},
		is_exists = {},
		is_executable = {},
	}

	local function reset_calls()
		calls.cmd = {}
		calls.is_in_path = {}
		calls.is_exists = {}
		calls.is_executable = {}
	end

	local env_ok = true
	local fs_exists = {}
	local fs_exec = {}

	local function install_mocks()
		package.preload["ward.process"] = function()
			return {
				cmd = function(...)
					local argv = { ... }
					local obj = {
						argv = argv,
						stdin_data = nil,
						stdin = function(self, data)
							self.stdin_data = data
							return self
						end,
					}
					table.insert(calls.cmd, obj)
					return obj
				end,
			}
		end

		package.preload["ward.env"] = function()
			return {
				is_in_path = function(bin)
					table.insert(calls.is_in_path, bin)
					return env_ok
				end,
			}
		end

		package.preload["ward.fs"] = function()
			return {
				is_exists = function(path)
					table.insert(calls.is_exists, path)
					return fs_exists[path] == true
				end,
				is_executable = function(path)
					table.insert(calls.is_executable, path)
					return fs_exec[path] == true
				end,
			}
		end

		package.loaded["ward.process"] = nil
		package.loaded["ward.env"] = nil
		package.loaded["ward.fs"] = nil
		for _, name in ipairs(MODULE_CANDIDATES) do
			package.loaded[name] = nil
		end
	end

	local function restore_originals()
		package.preload["ward.process"] = preload_orig["ward.process"]
		package.preload["ward.env"] = preload_orig["ward.env"]
		package.preload["ward.fs"] = preload_orig["ward.fs"]

		package.loaded["ward.process"] = loaded_orig["ward.process"]
		package.loaded["ward.env"] = loaded_orig["ward.env"]
		package.loaded["ward.fs"] = loaded_orig["ward.fs"]
		for _, name in ipairs(MODULE_CANDIDATES) do
			package.loaded[name] = loaded_orig[name]
		end
	end

	local function load_module()
		local errs = {}
		for _, name in ipairs(MODULE_CANDIDATES) do
			local ok, mod = pcall(require, name)
			if ok and type(mod) == "table" then
				t:ok(type(mod.Dconf) == "table", "module '" .. name .. "' did not return { Dconf = ... }")
				return mod
			end
			errs[#errs + 1] = name .. ": " .. tostring(mod)
		end
		t:ok(false, "failed to require dconf module. Tried:\n" .. table.concat(errs, "\n"))
	end

	local function last_cmd_obj() return calls.cmd[#calls.cmd] end

	t:before_all(function() install_mocks() end)

	t:after_all(function() restore_originals() end)

	t:before_each(function()
		reset_calls()
		env_ok = true
		fs_exists = {}
		fs_exec = {}
		for _, name in ipairs(MODULE_CANDIDATES) do
			package.loaded[name] = nil
		end
	end)

	t:test("read builds argv", function()
		local mod = load_module()
		local Dconf = mod.Dconf
		Dconf.bin = "dconf"

		Dconf.read("/org/test/key")

		t:eq(#calls.is_in_path, 1)
		t:eq(calls.is_in_path[1], "dconf")

		local cmd = last_cmd_obj()
		t:deep_eq(cmd.argv, { "dconf", "read", "/org/test/key" })
	end)

	t:test("write encodes strings and booleans", function()
		local mod = load_module()
		local Dconf = mod.Dconf
		Dconf.bin = "dconf"

		Dconf.write("/org/test/key", "hello")
		t:deep_eq(last_cmd_obj().argv, { "dconf", "write", "/org/test/key", "'hello'" })

		Dconf.write("/org/test/enabled", true)
		t:deep_eq(last_cmd_obj().argv, { "dconf", "write", "/org/test/enabled", "true" })
	end)

	t:test("encode escapes backslash and single quote", function()
		local mod = load_module()
		local Dconf = mod.Dconf
		t:eq(Dconf.encode("a\\b'c"), "'a\\\\b\\'c'")
	end)

	t:test("write supports raw gvariant", function()
		local mod = load_module()
		local Dconf = mod.Dconf
		Dconf.bin = "dconf"

		Dconf.write("/org/test/arr", Dconf.raw("[1, 2, 3]"))
		t:deep_eq(last_cmd_obj().argv, { "dconf", "write", "/org/test/arr", "[1, 2, 3]" })
	end)

	t:test("list/dump require trailing slash", function()
		local mod = load_module()
		local Dconf = mod.Dconf
		Dconf.bin = "dconf"

		Dconf.list("/org/test/")
		t:deep_eq(last_cmd_obj().argv, { "dconf", "list", "/org/test/" })

		Dconf.dump("/org/test/")
		t:deep_eq(last_cmd_obj().argv, { "dconf", "dump", "/org/test/" })

		local ok = pcall(function() Dconf.list("/org/test") end)
		t:falsy(ok)
	end)

	t:test("reset supports key and force dir", function()
		local mod = load_module()
		local Dconf = mod.Dconf
		Dconf.bin = "dconf"

		Dconf.reset("/org/test/key")
		t:deep_eq(last_cmd_obj().argv, { "dconf", "reset", "/org/test/key" })

		Dconf.reset("/org/test/", { force = true })
		t:deep_eq(last_cmd_obj().argv, { "dconf", "reset", "-f", "/org/test/" })
	end)

	t:test("load can attach stdin", function()
		local mod = load_module()
		local Dconf = mod.Dconf
		Dconf.bin = "dconf"

		local cmd = Dconf.load("/org/test/", "[section]\nkey='x'\n")
		t:deep_eq(cmd.argv, { "dconf", "load", "/org/test/" })
		t:eq(cmd.stdin_data, "[section]\nkey='x'\n")
	end)

	return t
end
