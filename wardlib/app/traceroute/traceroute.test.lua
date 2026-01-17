---@diagnostic disable: duplicate-set-field

-- Tinytest suite for traceroute module (init.lua)
--
-- This suite mocks ward modules used by app.traceroute:
--   * ward.process (cmd)
--   * ward.env     (is_in_path)
--   * ward.fs      (is_exists, is_executable)

return function(tinytest)
	local t = tinytest.new({ name = "traceroute" })

	local MODULE_CANDIDATES = { "wardlib.app.traceroute" }

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
				t:ok(type(mod.Traceroute) == "table", "module '" .. name .. "' did not return { Traceroute = ... }")
				return mod
			end
			errs[#errs + 1] = name .. ": " .. tostring(mod)
		end
		t:ok(false, "failed to require traceroute module. Tried:\n" .. table.concat(errs, "\n"))
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

	t:test("trace with icmp numeric max_ttl queries wait", function()
		local mod = load_module()
		local Traceroute = mod.Traceroute

		Traceroute.trace("example.com", { icmp = true, numeric = true, max_ttl = 16, queries = 1, wait = 2 })
		t:eq(calls.is_in_path[1], "traceroute")
		t:deep_eq(last_cmd(), { "traceroute", "-n", "-I", "-m", "16", "-q", "1", "-w", "2", "example.com" })
	end)

	t:test("trace tcp with port and packetlen", function()
		local mod = load_module()
		local Traceroute = mod.Traceroute

		Traceroute.trace("1.1.1.1", { inet4 = true, tcp = true, port = 443, packetlen = 60 })
		t:deep_eq(last_cmd(), { "traceroute", "-4", "-T", "-p", "443", "1.1.1.1", "60" })
	end)

	t:test("absolute bin validates via ward.fs", function()
		local mod = load_module()
		local Traceroute = mod.Traceroute

		Traceroute.bin = "/usr/bin/traceroute"
		fs_exists["/usr/bin/traceroute"] = true
		fs_exec["/usr/bin/traceroute"] = true

		Traceroute.trace("example.com", { inet6 = true })
		t:eq(calls.is_exists[1], "/usr/bin/traceroute")
		t:eq(calls.is_executable[1], "/usr/bin/traceroute")
		t:deep_eq(last_cmd(), { "/usr/bin/traceroute", "-6", "example.com" })
	end)

	return t
end
