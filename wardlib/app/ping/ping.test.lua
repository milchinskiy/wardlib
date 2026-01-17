---@diagnostic disable: duplicate-set-field

-- Tinytest suite for ping module (init.lua)
--
-- This suite mocks ward modules used by app.ping:
--   * ward.process (cmd)
--   * ward.env     (is_in_path)
--   * ward.fs      (is_exists, is_executable)

return function(tinytest)
	local t = tinytest.new({ name = "ping" })

	local MODULE_CANDIDATES = { "wardlib.app.ping" }

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
				t:ok(type(mod.Ping) == "table", "module '" .. name .. "' did not return { Ping = ... }")
				return mod
			end
			errs[#errs + 1] = name .. ": " .. tostring(mod)
		end
		t:ok(false, "failed to require ping module. Tried:\n" .. table.concat(errs, "\n"))
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

	t:test("ping with count interval size interface", function()
		local mod = load_module()
		local Ping = mod.Ping

		Ping.ping("1.1.1.1", { inet4 = true, count = 3, interval = 0.2, size = 56, interface = "eth0" })
		t:eq(calls.is_in_path[1], "ping")
		t:deep_eq(last_cmd(), { "ping", "-4", "-c", "3", "-i", "0.2", "-s", "56", "-I", "eth0", "1.1.1.1" })
	end)

	t:test("once forces -c 1", function()
		local mod = load_module()
		local Ping = mod.Ping

		Ping.once("example.com", { numeric = true })
		t:deep_eq(last_cmd(), { "ping", "-c", "1", "-n", "example.com" })
	end)

	t:test("absolute bin validates via ward.fs", function()
		local mod = load_module()
		local Ping = mod.Ping

		Ping.bin = "/usr/bin/ping"
		fs_exists["/usr/bin/ping"] = true
		fs_exec["/usr/bin/ping"] = true

		Ping.flood("8.8.8.8", nil)
		t:eq(calls.is_exists[1], "/usr/bin/ping")
		t:eq(calls.is_executable[1], "/usr/bin/ping")
		t:deep_eq(last_cmd(), { "/usr/bin/ping", "-f", "8.8.8.8" })
	end)

	return t
end
