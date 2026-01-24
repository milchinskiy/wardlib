---@diagnostic disable: duplicate-set-field

-- Tinytest suite for fuzzel module (init.lua)

return function(tinytest)
	local t = tinytest.new({ name = "fuzzel" })

	local MODULE = "wardlib.app.fuzzel"

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
		t:ok(ok and type(mod) == "table" and type(mod.Fuzzel) == "table", "module did not return { Fuzzel = ... }")
		return mod
	end

	local function last_cmd() return calls.cmd[#calls.cmd] end

	t:before_all(install_mocks)
	t:after_all(restore)
	t:before_each(reset)

	t:test("launcher builds argv", function()
		local Fuzzel = load_module().Fuzzel
		Fuzzel.launcher({ prompt = "Run", lines = 5, no_icons = true })
		t:deep_eq(last_cmd(), { "fuzzel", "-p", "Run", "-l", "5", "-I" })
	end)

	t:test("dmenu builds argv with --dmenu", function()
		local Fuzzel = load_module().Fuzzel
		Fuzzel.dmenu({ placeholder = "Type...", width = 40 })
		t:deep_eq(last_cmd(), { "fuzzel", "--dmenu", "--placeholder", "Type...", "-w", "40" })
	end)

	t:test("bin validation: PATH vs absolute", function()
		local Fuzzel = load_module().Fuzzel

		Fuzzel.bin = "fuzzel"
		env_ok = false
		local ok1 = pcall(function() Fuzzel.launcher(nil) end)
		t:falsy(ok1)
		t:eq(calls.is_in_path[#calls.is_in_path], "fuzzel")

		reset()
		Fuzzel = load_module().Fuzzel
		Fuzzel.bin = "/usr/bin/fuzzel"
		fs_exists["/usr/bin/fuzzel"] = true
		fs_exec["/usr/bin/fuzzel"] = true
		local ok2 = pcall(function() Fuzzel.launcher(nil) end)
		t:truthy(ok2)
		t:eq(calls.is_exists[#calls.is_exists], "/usr/bin/fuzzel")
		t:eq(calls.is_executable[#calls.is_executable], "/usr/bin/fuzzel")
	end)

	return t
end
