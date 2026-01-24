---@diagnostic disable: duplicate-set-field

-- Tinytest suite for dmenu module (init.lua)
--
-- Mocks:
--   * ward.process (cmd)
--   * ward.env     (is_in_path)
--   * ward.fs      (is_exists, is_executable)

return function(tinytest)
	local t = tinytest.new({ name = "dmenu" })

	local MODULE = "wardlib.app.dmenu"

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
		fs_exists, fs_exec = {}, {}
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

	local function load_module()
		local ok, mod = pcall(require, MODULE)
		t:ok(ok and type(mod) == "table" and type(mod.Dmenu) == "table", "module did not return { Dmenu = ... }")
		return mod
	end

	local function last_cmd() return calls.cmd[#calls.cmd] end

	t:before_all(install_mocks)
	t:after_all(restore)
	t:before_each(reset)

	t:test("menu builds argv with flags, values, and extra", function()
		local Dmenu = load_module().Dmenu
		Dmenu.menu({
			bottom = true,
			insensitive = true,
			lines = 10,
			monitor = 1,
			prompt = "Run:",
			font = "Iosevka-12",
			selected_bg = "#222222",
			selected_fg = "#ffffff",
			extra = { "-x" },
		})

		t:deep_eq(last_cmd(), {
			"dmenu",
			"-b",
			"-i",
			"-l",
			"10",
			"-m",
			"1",
			"-p",
			"Run:",
			"-fn",
			"Iosevka-12",
			"-sb",
			"#222222",
			"-sf",
			"#ffffff",
			"-x",
		})
	end)

	t:test("bin validation: PATH vs absolute", function()
		local Dmenu = load_module().Dmenu

		-- PATH bin
		Dmenu.bin = "dmenu"
		env_ok = false
		local ok1 = pcall(function() Dmenu.menu(nil) end)
		t:falsy(ok1)
		t:eq(calls.is_in_path[#calls.is_in_path], "dmenu")

		-- absolute bin
		reset()
		Dmenu = load_module().Dmenu
		Dmenu.bin = "/usr/bin/dmenu"
		fs_exists["/usr/bin/dmenu"] = true
		fs_exec["/usr/bin/dmenu"] = true
		local ok2 = pcall(function() Dmenu.menu(nil) end)
		t:truthy(ok2)
		t:eq(calls.is_exists[#calls.is_exists], "/usr/bin/dmenu")
		t:eq(calls.is_executable[#calls.is_executable], "/usr/bin/dmenu")
	end)

	return t
end
