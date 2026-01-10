---@diagnostic disable: duplicate-set-field

-- Tinytest suite for ip module (init.lua)
--
-- This suite mocks ward modules used by app.ip:
--   * ward.process (cmd)
--   * ward.env     (is_in_path)
--   * ward.fs      (is_exists, is_executable)

return function(tinytest)
	local t = tinytest.new({ name = "ip" })

	local MODULE_CANDIDATES = { "app.ip" }

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
				t:ok(type(mod.Ip) == "table", "module '" .. name .. "' did not return { Ip = ... }")
				return mod
			end
			errs[#errs + 1] = name .. ": " .. tostring(mod)
		end
		t:ok(false, "failed to require ip module. Tried:\n" .. table.concat(errs, "\n"))
	end

	local function last_cmd()
		return calls.cmd[#calls.cmd]
	end

	t:before_all(function()
		install_mocks()
	end)

	t:after_all(function()
		restore_originals()
	end)

	t:before_each(function()
		reset_calls()
		env_ok = true
		fs_exists = {}
		fs_exec = {}
		for _, name in ipairs(MODULE_CANDIDATES) do
			package.loaded[name] = nil
		end
	end)

	-- -------------------------
	-- Tests
	-- -------------------------

	t:test("addr show with json+pretty and dev selector", function()
		local mod = load_module()
		local Ip = mod.Ip

		Ip.addr_show("eth0", { json = true, pretty = true })
		t:eq(calls.is_in_path[1], "ip")
		t:deep_eq(last_cmd(), { "ip", "-j", "-p", "addr", "show", "dev", "eth0" })
	end)

	t:test("route add default via dev metric table", function()
		local mod = load_module()
		local Ip = mod.Ip

		Ip.route_add("default", {
			inet4 = true,
			via = "192.0.2.1",
			dev = "eth0",
			metric = 100,
			table = 100,
		})
		t:deep_eq(last_cmd(), {
			"ip",
			"-4",
			"route",
			"add",
			"default",
			"via",
			"192.0.2.1",
			"dev",
			"eth0",
			"metric",
			"100",
			"table",
			"100",
		})
	end)

	t:test("link set up mtu and move to netns", function()
		local mod = load_module()
		local Ip = mod.Ip

		Ip.link_set("eth0", { up = true, mtu = 1500, set_netns = "ns1" })
		t:deep_eq(last_cmd(), { "ip", "link", "set", "dev", "eth0", "up", "mtu", "1500", "netns", "ns1" })
	end)

	t:test("absolute bin validates via ward.fs", function()
		local mod = load_module()
		local Ip = mod.Ip

		Ip.bin = "/usr/sbin/ip"
		fs_exists["/usr/sbin/ip"] = true
		fs_exec["/usr/sbin/ip"] = true

		Ip.addr_show("lo", { oneline = true })
		t:eq(calls.is_exists[1], "/usr/sbin/ip")
		t:eq(calls.is_executable[1], "/usr/sbin/ip")
		t:deep_eq(last_cmd(), { "/usr/sbin/ip", "-o", "addr", "show", "dev", "lo" })
	end)

	return t
end
