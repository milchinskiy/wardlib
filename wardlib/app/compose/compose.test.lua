---@diagnostic disable: duplicate-set-field

-- Tinytest suite for compose module (init.lua)

return function(tinytest)
	local t = tinytest.new({ name = "compose" })
	local MODULE = "wardlib.app.compose"

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

	local function last_cmd() return calls.cmd[#calls.cmd] end

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

	t:test("defaults to docker engine", function()
		local Compose = require(MODULE).Compose
		Compose.up(nil, { file = "compose.yml", detach = true })
		t:eq(calls.is_in_path[1], "docker")
		t:deep_eq(last_cmd().argv, { "docker", "compose", "up", "-f", "compose.yml", "-d" })
	end)

	t:test("uses podman engine when engine='podman'", function()
		local Compose = require(MODULE).Compose
		Compose.down({ engine = "podman", remove_orphans = true })
		t:eq(calls.is_in_path[1], "podman")
		t:deep_eq(last_cmd().argv, { "podman", "compose", "down", "--remove-orphans" })
	end)

	t:test("exec builds argv with env and workdir", function()
		local Compose = require(MODULE).Compose
		Compose.exec("web", { "sh", "-lc", "id" }, {
			file = { "a.yml", "b.yml" },
			workdir = "/w",
			env = "A=1",
		})
		t:deep_eq(last_cmd().argv, {
			"docker",
			"compose",
			"exec",
			"-f",
			"a.yml",
			"-f",
			"b.yml",
			"-w",
			"/w",
			"-e",
			"A=1",
			"web",
			"sh",
			"-lc",
			"id",
		})
	end)

	t:test("run builds argv with publish/volume", function()
		local Compose = require(MODULE).Compose
		Compose.run("web", "env", {
			rm = true,
			publish = { "8080:80" },
			volume = "./x:/x",
		})
		t:deep_eq(last_cmd().argv, {
			"docker",
			"compose",
			"run",
			"--rm",
			"-p",
			"8080:80",
			"-v",
			"./x:/x",
			"web",
			"env",
		})
	end)

	return t
end
