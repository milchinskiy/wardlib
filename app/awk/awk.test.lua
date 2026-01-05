---@diagnostic disable: duplicate-set-field

-- Tinytest suite for awk module (init.lua)
--
-- This suite mocks ward modules used by app.awk:
--   * ward.process (cmd)
--   * ward.env     (is_in_path)
--   * ward.fs      (is_exists, is_executable)

return function(tinytest)
	local t = tinytest.new({ name = "awk" })

	local MODULE_CANDIDATES = { "app.awk" }

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
		fs_exists, fs_exec = {}, {}
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
		local ok, mod = pcall(require, "app.awk")
		t:ok(ok and type(mod) == "table" and type(mod.Awk) == "table", "module did not return { Awk = ... }")
		return mod
	end

	local function last_cmd()
		return calls.cmd[#calls.cmd]
	end

	t:before_all(install_mocks)
	t:after_all(restore)
	t:before_each(reset)

	t:test("cmd builds argv", function()
		local mod = load_module()
		local Awk = mod.Awk

		local cmd = Awk.cmd({ "--version" })
		t:eq(cmd.argv[1], "awk")
		t:eq(cmd.argv[2], "--version")
		t:deep_eq(last_cmd(), { "awk", "--version" })
	end)

	t:test("eval builds argv with deterministic vars/assigns and inputs", function()
		local mod = load_module()
		local Awk = mod.Awk

		Awk.bin = "awk"
		env_ok = true

		Awk.eval("{print $1}", { "in1", "in2" }, {
			extra = { "--" },
			posix = true,
			field_sep = ":",
			includes = { "/tmp/inc1.awk" },
			vars = { b = 2, a = "x" },
			assigns = { z = 9, y = "t" },
		})

		t:deep_eq(last_cmd(), {
			"awk",
			"--",
			"--posix",
			"-F",
			":",
			"-i",
			"/tmp/inc1.awk",
			"-v",
			"a=x",
			"-v",
			"b=2",
			"{print $1}",
			"y=t",
			"z=9",
			"in1",
			"in2",
		})
	end)

	t:test("source uses repeated -e", function()
		local mod = load_module()
		local Awk = mod.Awk

		Awk.source({ "BEGIN{a=1}", "{print a}" }, nil, { vars = { a = 123 } })

		t:deep_eq(last_cmd(), {
			"awk",
			"-v",
			"a=123",
			"-e",
			"BEGIN{a=1}",
			"-e",
			"{print a}",
		})
	end)

	t:test("file uses repeated -f", function()
		local mod = load_module()
		local Awk = mod.Awk

		Awk.file({ "/tmp/a.awk", "/tmp/b.awk" }, "input.txt", { assigns = { "x=1", "y=2" } })

		t:deep_eq(last_cmd(), {
			"awk",
			"-f",
			"/tmp/a.awk",
			"-f",
			"/tmp/b.awk",
			"x=1",
			"y=2",
			"input.txt",
		})
	end)

	t:test("bin validation: PATH vs absolute", function()
		local mod = load_module()
		local Awk = mod.Awk

		-- PATH bin
		Awk.bin = "awk"
		env_ok = false
		local ok1 = pcall(function()
			Awk.cmd({ "--version" })
		end)
		t:falsy(ok1)
		t:eq(calls.is_in_path[#calls.is_in_path], "awk")

		-- absolute bin
		reset()
		Awk.bin = "/usr/bin/awk"
		fs_exists["/usr/bin/awk"] = true
		fs_exec["/usr/bin/awk"] = true
		local ok2 = pcall(function()
			Awk.cmd({ "--version" })
		end)
		t:truthy(ok2)
		t:eq(calls.is_exists[#calls.is_exists], "/usr/bin/awk")
		t:eq(calls.is_executable[#calls.is_executable], "/usr/bin/awk")
	end)

	return t
end
