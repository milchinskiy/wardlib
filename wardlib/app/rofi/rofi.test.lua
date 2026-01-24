---@diagnostic disable: duplicate-set-field

-- Tinytest suite for rofi module (init.lua)

return function(tinytest)
	local t = tinytest.new({ name = "rofi" })

	local MODULE = "wardlib.app.rofi"

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
		t:ok(ok and type(mod) == "table" and type(mod.Rofi) == "table", "module did not return { Rofi = ... }")
		return mod
	end

	local function last_cmd() return calls.cmd[#calls.cmd] end

	t:before_all(install_mocks)
	t:after_all(restore)
	t:before_each(reset)

	t:test("dmenu builds argv with common and dmenu options", function()
		local Rofi = load_module().Rofi
		Rofi.dmenu({
			config = "rofi.rasi",
			theme = "mytheme",
			show_icons = true,
			prompt = "Run",
			lines = 8,
			insensitive = true,
			no_custom = true,
			extra = { "-no-fixed-num-lines" },
		})

		t:deep_eq(last_cmd(), {
			"rofi",
			"-config",
			"rofi.rasi",
			"-theme",
			"mytheme",
			"-show-icons",
			"-dmenu",
			"-p",
			"Run",
			"-l",
			"8",
			"-i",
			"-no-custom",
			"-no-fixed-num-lines",
		})
	end)

	t:test("show builds argv with -show and mode", function()
		local Rofi = load_module().Rofi
		Rofi.show("run", { modi = "run,drun", terminal = "foot", extra = { "-matching", "fuzzy" } })
		t:deep_eq(last_cmd(), {
			"rofi",
			"-modi",
			"run,drun",
			"-terminal",
			"foot",
			"-show",
			"run",
			"-matching",
			"fuzzy",
		})
	end)

	t:test("bin validation: PATH vs absolute", function()
		local Rofi = load_module().Rofi

		-- PATH bin
		Rofi.bin = "rofi"
		env_ok = false
		local ok1 = pcall(function() Rofi.show("run", nil) end)
		t:falsy(ok1)
		t:eq(calls.is_in_path[#calls.is_in_path], "rofi")

		-- absolute bin
		reset()
		Rofi = load_module().Rofi
		Rofi.bin = "/usr/bin/rofi"
		fs_exists["/usr/bin/rofi"] = true
		fs_exec["/usr/bin/rofi"] = true
		local ok2 = pcall(function() Rofi.show("run", nil) end)
		t:truthy(ok2)
		t:eq(calls.is_exists[#calls.is_exists], "/usr/bin/rofi")
		t:eq(calls.is_executable[#calls.is_executable], "/usr/bin/rofi")
	end)

	return t
end
