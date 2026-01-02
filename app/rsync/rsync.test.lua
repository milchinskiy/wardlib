---@diagnostic disable: duplicate-set-field

-- Tinytest suite for rsync module (init.lua)

return function(tinytest)
	local t = tinytest.new({ name = "rsync" })
	local MODULE_CANDIDATES = { "app.rsync" }

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

	local calls = { cmd = {}, is_in_path = {}, is_exists = {}, is_executable = {} }
	local env_ok = true
	local fs_exists, fs_exec = {}, {}

	local function reset()
		calls.cmd, calls.is_in_path, calls.is_exists, calls.is_executable = {}, {}, {}, {}
		env_ok = true
		fs_exists = {}
		fs_exec = {}
		for _, name in ipairs(MODULE_CANDIDATES) do
			package.loaded[name] = nil
		end
	end

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
		package.loaded["ward.process"], package.loaded["ward.env"], package.loaded["ward.fs"] = nil, nil, nil
	end

	local function restore()
		package.preload["ward.process"], package.preload["ward.env"], package.preload["ward.fs"] =
			preload_orig["ward.process"], preload_orig["ward.env"], preload_orig["ward.fs"]
		package.loaded["ward.process"], package.loaded["ward.env"], package.loaded["ward.fs"] =
			loaded_orig["ward.process"], loaded_orig["ward.env"], loaded_orig["ward.fs"]
		for _, name in ipairs(MODULE_CANDIDATES) do
			package.loaded[name] = loaded_orig[name]
		end
	end

	local function load_module()
		local ok, mod = pcall(require, "app.rsync")
		t:ok(ok and type(mod) == "table" and type(mod.Rsync) == "table", "module did not return { Rsync = ... }")
		return mod
	end

	local function last_cmd()
		return calls.cmd[#calls.cmd]
	end

	t:before_all(install_mocks)
	t:after_all(restore)
	t:before_each(reset)

	t:test("sync builds argv with common flags", function()
		local mod = load_module()
		local Rsync = mod.Rsync

		Rsync.sync({ "a/", "b/" }, "host:/dst/", {
			archive = true,
			compress = true,
			delete = true,
			rsh = "ssh -p 2222",
			excludes = { ".git", "target" },
		})

		t:eq(calls.is_in_path[1], "rsync")
		t:deep_eq(last_cmd(), {
			"rsync",
			"-a",
			"-z",
			"--delete",
			"-e",
			"ssh -p 2222",
			"--exclude",
			".git",
			"--exclude",
			"target",
			"a/",
			"b/",
			"host:/dst/",
		})
	end)

	return t
end
