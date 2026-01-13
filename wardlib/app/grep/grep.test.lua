---@diagnostic disable: duplicate-set-field

-- Tinytest suite for grep module (init.lua)
--
-- This suite mocks ward modules used by app.grep:
--   * ward.process (cmd)
--   * ward.env     (is_in_path)
--   * ward.fs      (is_exists, is_executable)

return function(tinytest)
	local t = tinytest.new({ name = "grep" })

	local MODULE = "wardlib.app.grep"

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
		t:ok(ok and type(mod) == "table" and type(mod.Grep) == "table", "module did not return { Grep = ... }")
		return mod
	end

	local function last_cmd()
		return calls.cmd[#calls.cmd]
	end

	t:before_all(install_mocks)
	t:after_all(restore)
	t:before_each(reset)

	t:test("search builds argv with repeatable -e, context, and include", function()
		local Grep = load_module().Grep

		Grep.search({ "foo", "bar" }, { "a.txt", "b.txt" }, {
			extended = true,
			ignore_case = true,
			line_number = true,
			after_context = 2,
			color = true,
			include = "*.txt",
		})

		t:deep_eq(last_cmd(), {
			"grep",
			"-E",
			"-i",
			"-n",
			"-A",
			"2",
			"--color=auto",
			"--include=*.txt",
			"-e",
			"foo",
			"-e",
			"bar",
			"a.txt",
			"b.txt",
		})
	end)

	t:test("count_matches sets -c", function()
		local Grep = load_module().Grep
		Grep.count_matches("x", "f", { fixed = true })
		t:deep_eq(last_cmd(), { "grep", "-F", "-c", "-e", "x", "f" })
	end)

	t:test("bin validation: PATH vs absolute", function()
		local Grep = load_module().Grep

		-- PATH bin
		Grep.bin = "grep"
		env_ok = false
		local ok1 = pcall(function()
			Grep.search("x", "f", nil)
		end)
		t:falsy(ok1)
		t:eq(calls.is_in_path[#calls.is_in_path], "grep")

		-- absolute bin
		reset()
		Grep.bin = "/usr/bin/grep"
		fs_exists["/usr/bin/grep"] = true
		fs_exec["/usr/bin/grep"] = true
		local ok2 = pcall(function()
			Grep.search("x", "f", nil)
		end)
		t:truthy(ok2)
		t:eq(calls.is_exists[#calls.is_exists], "/usr/bin/grep")
		t:eq(calls.is_executable[#calls.is_executable], "/usr/bin/grep")
	end)

	return t
end
