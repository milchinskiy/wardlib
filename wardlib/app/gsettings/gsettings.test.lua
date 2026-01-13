---@diagnostic disable: duplicate-set-field

-- Tinytest suite for gsettings module (init.lua)

return function(tinytest)
	local t = tinytest.new({ name = "gsettings" })
	local MODULE = "wardlib.app.gsettings"

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

	local calls = { cmd = {}, is_in_path = {}, is_exists = {}, is_executable = {} }
	local env_ok = true
	local fs_exists, fs_exec = {}, {}

	local function reset()
		calls.cmd, calls.is_in_path, calls.is_exists, calls.is_executable = {}, {}, {}, {}
		env_ok = true
		fs_exists = {}
		fs_exec = {}
		package.loaded[MODULE] = nil
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
		package.loaded[MODULE] = loaded_orig[MODULE]
	end

	local function last_cmd()
		return calls.cmd[#calls.cmd]
	end
	local function load()
		local ok, mod = pcall(require, MODULE)
		t:ok(
			ok and type(mod) == "table" and type(mod.Gsettings) == "table",
			"module did not return { Gsettings = ... }"
		)
		return mod
	end

	t:before_all(install_mocks)
	t:after_all(restore)
	t:before_each(reset)

	t:test("get builds argv", function()
		local Gsettings = load().Gsettings
		Gsettings.get("org.gnome.desktop.interface", "clock-show-date")
		t:eq(calls.is_in_path[1], "gsettings")
		t:deep_eq(last_cmd(), { "gsettings", "get", "org.gnome.desktop.interface", "clock-show-date" })
	end)

	t:test("set builds argv", function()
		local Gsettings = load().Gsettings
		Gsettings.set("org.gnome.desktop.interface", "clock-show-date", "true")
		t:deep_eq(last_cmd(), { "gsettings", "set", "org.gnome.desktop.interface", "clock-show-date", "true" })
	end)

	return t
end
