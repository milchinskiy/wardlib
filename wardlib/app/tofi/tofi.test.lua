---@diagnostic disable: duplicate-set-field

-- Tinytest suite for tofi module (init.lua)

return function(tinytest)
	local t = tinytest.new({ name = "tofi" })

	local MODULE = "wardlib.app.tofi"

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
		t:ok(ok and type(mod) == "table" and type(mod.Tofi) == "table", "module did not return { Tofi = ... }")
		return mod
	end

	local function last_cmd() return calls.cmd[#calls.cmd] end

	t:before_all(install_mocks)
	t:after_all(restore)
	t:before_each(reset)

	t:test("run builds argv with modeled options, defines, and extra", function()
		local Tofi = load_module().Tofi
		Tofi.run({
			config = "tofi.conf",
			prompt_text = "Run",
			require_match = true,
			width = "40%",
			defines = { a = 1, m = "x", z = true },
			extra = { "--some-flag" },
		})

		t:deep_eq(last_cmd(), {
			"tofi-run",
			"-c",
			"tofi.conf",
			"--prompt-text",
			"Run",
			"--width",
			"40%",
			"--require-match",
			"--a",
			"1",
			"--m",
			"x",
			"--z",
			"--some-flag",
		})
	end)

	t:test("bin validation: PATH vs absolute", function()
		local Tofi = load_module().Tofi

		-- PATH bin
		Tofi.bin_run = "tofi-run"
		env_ok = false
		local ok1 = pcall(function() Tofi.run(nil) end)
		t:falsy(ok1)
		t:eq(calls.is_in_path[#calls.is_in_path], "tofi-run")

		-- absolute bin
		reset()
		Tofi = load_module().Tofi
		Tofi.bin_run = "/usr/bin/tofi-run"
		fs_exists["/usr/bin/tofi-run"] = true
		fs_exec["/usr/bin/tofi-run"] = true
		local ok2 = pcall(function() Tofi.run(nil) end)
		t:truthy(ok2)
		t:eq(calls.is_exists[#calls.is_exists], "/usr/bin/tofi-run")
		t:eq(calls.is_executable[#calls.is_executable], "/usr/bin/tofi-run")
	end)

	return t
end
