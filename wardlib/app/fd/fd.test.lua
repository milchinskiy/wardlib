---@diagnostic disable: duplicate-set-field

-- Tinytest suite for fd module (init.lua)
--
-- This suite mocks ward modules used by fd:
--   * ward.process (cmd)
--   * ward.env     (is_in_path)
--   * ward.fs      (is_exists, is_executable)

return function(tinytest)
	local t = tinytest.new({ name = "fd" })

	local MODULE_CANDIDATES = { "wardlib.app.fd" }

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
				t:ok(type(mod.Fd) == "table", "module '" .. name .. "' did not return { Fd = ... }")
				return mod
			end
			errs[#errs + 1] = name .. ": " .. tostring(mod)
		end
		t:ok(false, "failed to require fd module. Tried:\n" .. table.concat(errs, "\n"))
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

	t:test("search emits opts + pattern + paths", function()
		local mod = load_module()
		local Fd = mod.Fd

		Fd.search("needle", { ".", "/var/log" }, { hidden = true, no_ignore = true, max_depth = 2 })
		t:eq(calls.is_in_path[1], "fd")
		t:deep_eq(last_cmd_obj().argv, { "fd", "-H", "-I", "-d", "2", "needle", ".", "/var/log" })
	end)

	t:test("repeatable extension/type/exclude", function()
		local mod = load_module()
		local Fd = mod.Fd

		Fd.search(".", nil, {
			extension = { "lua", "md" },
			type = { "f", "l" },
			exclude = "node_modules",
		})
		t:deep_eq(last_cmd_obj().argv, {
			"fd",
			"-t",
			"f",
			"-t",
			"l",
			"-e",
			"lua",
			"-e",
			"md",
			"-E",
			"node_modules",
			".",
		})
	end)

	t:test("exec and exec_batch are mutually exclusive", function()
		local mod = load_module()
		local Fd = mod.Fd

		local ok = pcall(function() Fd.search(".", nil, { exec = { "echo", "x" }, exec_batch = { "echo", "y" } }) end)
		t:falsy(ok)
	end)

	return t
end
