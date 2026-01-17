---@diagnostic disable: duplicate-set-field

-- Tinytest suite for archive module (init.lua)
--
-- This suite mocks ward modules used by app.archive:
--   * ward.process (cmd)
--   * ward.env     (is_in_path)
--   * ward.fs      (is_exists, is_executable)

return function(tinytest)
	local t = tinytest.new({ name = "archive" })

	local MODULE_CANDIDATES = { "wardlib.app.archive" }

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
					table.insert(calls.cmd, argv)
					return { argv = argv }
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
				t:ok(type(mod.Archive) == "table", "module '" .. name .. "' did not return { Archive = ... }")
				return mod
			end
			errs[#errs + 1] = name .. ": " .. tostring(mod)
		end
		t:ok(false, "failed to require archive module. Tried:\n" .. table.concat(errs, "\n"))
	end

	local function last_cmd() return calls.cmd[#calls.cmd] end

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

	t:test("create builds tar argv with -C and compression", function()
		local mod = load_module()
		local Archive = mod.Archive

		Archive.create("/tmp/a.tar.gz", { "file1", "dir2" }, { dir = "/home/me", compression = "gz" })
		t:eq(calls.is_in_path[1], "tar")
		t:deep_eq(last_cmd(), { "tar", "-c", "-z", "-C", "/home/me", "-f", "/tmp/a.tar.gz", "file1", "dir2" })
	end)

	t:test("extract builds argv with destination and strip-components", function()
		local mod = load_module()
		local Archive = mod.Archive

		Archive.extract("/tmp/a.tar", { to = "/tmp/out", strip_components = 1 })
		t:deep_eq(last_cmd(), { "tar", "-x", "-f", "/tmp/a.tar", "--strip-components=1", "-C", "/tmp/out" })
	end)

	t:test("list builds argv", function()
		local mod = load_module()
		local Archive = mod.Archive

		Archive.list("/tmp/a.tar", { verbose = true })
		t:deep_eq(last_cmd(), { "tar", "-t", "-v", "-f", "/tmp/a.tar" })
	end)

	t:test("rejects unsupported compression", function()
		local mod = load_module()
		local Archive = mod.Archive

		local ok = pcall(function() Archive.list("/tmp/a.tar", { compression = "bzip2" }) end)
		t:falsy(ok)
	end)

	return t
end
