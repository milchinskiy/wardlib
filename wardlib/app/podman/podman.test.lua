---@diagnostic disable: duplicate-set-field

-- Tinytest suite for podman module (init.lua)

return function(tinytest)
	local t = tinytest.new({ name = "podman" })
	local MODULE = "wardlib.app.podman"

	local preload_orig = {
		["ward.process"] = package.preload["ward.process"],
		["ward.env"] = package.preload["ward.env"],
		["ward.fs"] = package.preload["ward.fs"],
	}
	local loaded_orig = {
		["ward.process"] = package.loaded["ward.process"],
		["ward.env"] = package.loaded["ward.env"],
		["ward.fs"] = package.loaded["ward.fs"],
		[MODULE] = package.loaded[MODULE],
	}

	local calls = {
		cmd = {},
		is_in_path = {},
		is_exists = {},
		is_executable = {},
	}

	local env_ok = true
	local fs_exists = {}
	local fs_exec = {}

	local function install_mocks()
		package.preload["ward.process"] = function()
			return {
				cmd = function(...)
					local obj = { argv = { ... } }
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
		package.loaded[MODULE] = nil
	end

	local function restore_originals()
		package.preload["ward.process"] = preload_orig["ward.process"]
		package.preload["ward.env"] = preload_orig["ward.env"]
		package.preload["ward.fs"] = preload_orig["ward.fs"]

		package.loaded["ward.process"] = loaded_orig["ward.process"]
		package.loaded["ward.env"] = loaded_orig["ward.env"]
		package.loaded["ward.fs"] = loaded_orig["ward.fs"]
		package.loaded[MODULE] = loaded_orig[MODULE]
	end

	local function last_cmd()
		return calls.cmd[#calls.cmd]
	end

	t:before_all(install_mocks)
	t:after_all(restore_originals)

	t:before_each(function()
		calls.cmd = {}
		calls.is_in_path = {}
		calls.is_exists = {}
		calls.is_executable = {}
		env_ok = true
		fs_exists = {}
		fs_exec = {}
		package.loaded[MODULE] = nil
	end)

	t:test("run builds argv with repeatable env/publish", function()
		local Podman = require(MODULE).Podman
		Podman.run("alpine:3", { "sh", "-lc", "echo ok" }, {
			rm = true,
			name = "t",
			env = { "A=1", "B=2" },
			publish = "8080:80",
		})
		t:eq(calls.is_in_path[1], "podman")
		t:deep_eq(last_cmd().argv, {
			"podman",
			"run",
			"--rm",
			"--name",
			"t",
			"-e",
			"A=1",
			"-e",
			"B=2",
			"-p",
			"8080:80",
			"alpine:3",
			"sh",
			"-lc",
			"echo ok",
		})
	end)

	t:test("build builds argv with tag/build-arg", function()
		local Podman = require(MODULE).Podman
		Podman.build(".", {
			tag = { "x:1", "x:latest" },
			file = "Containerfile",
			build_arg = { "A=1" },
			no_cache = true,
			layers = true,
		})
		t:deep_eq(last_cmd().argv, {
			"podman",
			"build",
			"-t",
			"x:1",
			"-t",
			"x:latest",
			"-f",
			"Containerfile",
			"--build-arg",
			"A=1",
			"--no-cache",
			"--layers",
			".",
		})
	end)

	t:test("ps adds filters", function()
		local Podman = require(MODULE).Podman
		Podman.ps({ all = true, filter = { "status=running", "label=a=b" } })
		t:deep_eq(last_cmd().argv, { "podman", "ps", "-a", "--filter", "status=running", "--filter", "label=a=b" })
	end)

	t:test("logs adds tail and since", function()
		local Podman = require(MODULE).Podman
		Podman.logs("c1", { follow = true, tail = 100, since = "10m" })
		t:deep_eq(last_cmd().argv, { "podman", "logs", "-f", "--since", "10m", "--tail", "100", "c1" })
	end)

	t:test("login supports password-stdin", function()
		local Podman = require(MODULE).Podman
		Podman.login("ghcr.io", { username = "u", password_stdin = true })
		t:deep_eq(last_cmd().argv, { "podman", "login", "-u", "u", "--password-stdin", "ghcr.io" })
	end)

	return t
end
