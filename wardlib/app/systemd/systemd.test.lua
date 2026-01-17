---@diagnostic disable: duplicate-set-field

-- Tinytest suite for systemd module (init.lua)
--
-- This suite mocks ward modules used by systemd:
--   * ward.process (cmd)
--   * ward.env     (is_in_path)
--   * ward.fs      (is_exists, is_executable)
--
-- It asserts that the produced argv is correct and flags are in the expected order.

return function(tinytest)
	local t = tinytest.new({ name = "systemd" })

	local MODULE_CANDIDATES = { "wardlib.app.systemd" }

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
				t:ok(type(mod.Systemd) == "table", "module '" .. name .. "' did not return { Systemd = ... }")
				return mod
			end
			errs[#errs + 1] = name .. ": " .. tostring(mod)
		end
		t:ok(false, "failed to require systemd module. Tried:\n" .. table.concat(errs, "\n"))
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

	-- -------------------------
	-- Tests
	-- -------------------------

	t:test("start builds argv", function()
		local mod = load_module()
		local Systemd = mod.Systemd

		Systemd.systemctl_bin = "systemctl"
		Systemd.start("nginx.service")

		t:eq(calls.is_in_path[1], "systemctl")
		t:deep_eq(last_cmd(), { "systemctl", "start", "nginx.service" })
	end)

	t:test("start supports --user", function()
		local mod = load_module()
		local Systemd = mod.Systemd

		Systemd.start("syncthing.service", { user = true })
		t:deep_eq(last_cmd(), { "systemctl", "--user", "start", "syncthing.service" })
	end)

	t:test("enable supports --now", function()
		local mod = load_module()
		local Systemd = mod.Systemd

		Systemd.enable("syncthing.service", { now = true })
		t:deep_eq(last_cmd(), { "systemctl", "enable", "--now", "syncthing.service" })
	end)

	t:test("status defaults to --no-pager", function()
		local mod = load_module()
		local Systemd = mod.Systemd

		Systemd.status("ssh.service")
		t:deep_eq(last_cmd(), { "systemctl", "status", "--no-pager", "ssh.service" })
	end)

	t:test("status can disable --no-pager", function()
		local mod = load_module()
		local Systemd = mod.Systemd

		Systemd.status("ssh.service", { no_pager = false })
		t:deep_eq(last_cmd(), { "systemctl", "status", "ssh.service" })
	end)

	t:test("journal builds argv with common flags", function()
		local mod = load_module()
		local Systemd = mod.Systemd

		Systemd.journalctl_bin = "journalctl"
		Systemd.journal("nginx.service", {
			follow = true,
			lines = 200,
			since = "yesterday",
			priority = "err",
			output = "cat",
		})

		t:eq(calls.is_in_path[#calls.is_in_path], "journalctl")
		t:deep_eq(last_cmd(), {
			"journalctl",
			"--no-pager",
			"-u",
			"nginx.service",
			"-f",
			"-n",
			"200",
			"--since",
			"yesterday",
			"-p",
			"err",
			"-o",
			"cat",
		})
	end)

	t:test("journal supports --user and keeps ordering", function()
		local mod = load_module()
		local Systemd = mod.Systemd

		Systemd.journal("pipewire.service", { user = true, follow = true })
		t:deep_eq(last_cmd(), { "journalctl", "--user", "--no-pager", "-u", "pipewire.service", "-f" })
	end)

	t:test("rejects unit starting with '-'", function()
		local mod = load_module()
		local Systemd = mod.Systemd

		local ok = pcall(function() Systemd.start("-f") end)
		t:falsy(ok)
	end)

	return t
end
