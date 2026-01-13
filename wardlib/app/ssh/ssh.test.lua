---@diagnostic disable: duplicate-set-field

-- Tinytest suite for ssh module (init.lua)
--
-- This suite mocks ward modules used by app.ssh:
--   * ward.process (cmd)
--   * ward.env     (is_in_path)
--   * ward.fs      (is_exists, is_executable)

return function(tinytest)
	local t = tinytest.new({ name = "ssh" })

	local MODULE_CANDIDATES = { "wardlib.app.ssh" }

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
				t:ok(type(mod.Ssh) == "table", "module '" .. name .. "' did not return { Ssh = ... }")
				return mod
			end
			errs[#errs + 1] = name .. ": " .. tostring(mod)
		end
		t:ok(false, "failed to require ssh module. Tried:\n" .. table.concat(errs, "\n"))
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

	t:test("ssh.exec builds argv", function()
		local mod = load_module()
		local Ssh = mod.Ssh

		Ssh.exec("example.com", { "echo", "hi" }, {
			user = "me",
			port = 2222,
			identity_file = "~/.ssh/id_ed25519",
			batch = true,
			strict_host_key_checking = "accept-new",
			known_hosts_file = "/tmp/kh",
			connect_timeout = 5,
			extra = { "-v" },
		})

		t:eq(calls.is_in_path[1], "ssh")
		t:deep_eq(last_cmd(), {
			"ssh",
			"-p",
			"2222",
			"-i",
			"~/.ssh/id_ed25519",
			"-o",
			"BatchMode=yes",
			"-o",
			"StrictHostKeyChecking=accept-new",
			"-o",
			"UserKnownHostsFile=/tmp/kh",
			"-o",
			"ConnectTimeout=5",
			"-v",
			"me@example.com",
			"echo",
			"hi",
		})
	end)

	t:test("copy_to builds scp argv and remote path", function()
		local mod = load_module()
		local Ssh = mod.Ssh

		Ssh.copy_to("example.com", "./local.txt", "/tmp/remote.txt", {
			user = "me",
			port = 2200,
			recursive = true,
			compress = true,
		})

		t:eq(calls.is_in_path[1], "scp")
		t:deep_eq(last_cmd(), {
			"scp",
			"-P",
			"2200",
			"-r",
			"-C",
			"./local.txt",
			"me@example.com:/tmp/remote.txt",
		})
	end)

	t:test("rejects flag-like host", function()
		local mod = load_module()
		local Ssh = mod.Ssh

		local ok = pcall(function()
			Ssh.exec("-bad", nil, nil)
		end)
		t:falsy(ok)
	end)

	return t
end
