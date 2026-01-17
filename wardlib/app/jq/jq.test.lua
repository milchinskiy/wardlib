---@diagnostic disable: duplicate-set-field

-- Tinytest suite for jq module (init.lua)
--
-- This suite mocks ward modules used by app.jq:
--   * ward.process (cmd)
--   * ward.env     (is_in_path)
--   * ward.fs      (is_exists, is_executable)

return function(tinytest)
	local t = tinytest.new({ name = "jq" })

	local MODULE_CANDIDATES = { "wardlib.app.jq" }

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

	local calls = {
		cmd = {},
		is_in_path = {},
		is_exists = {},
		is_executable = {},
	}

	local function reset_calls()
		calls.cmd = {}
		calls.is_in_path = {}
		calls.is_exists = {}
		calls.is_executable = {}
	end

	local env_ok = true
	local fs_exists = {}
	local fs_exec = {}

	local function install_mocks()
		package.preload["ward.process"] = function()
			return {
				cmd = function(...)
					local argv = { ... }
					local obj = {
						argv = argv,
						stdin_data = nil,
						stdin = function(self, data)
							self.stdin_data = data
							return self
						end,
					}
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
		for _, name in ipairs(MODULE_CANDIDATES) do
			package.loaded[name] = nil
		end
	end

	local function restore_originals()
		package.preload["ward.process"] = preload_orig["ward.process"]
		package.preload["ward.env"] = preload_orig["ward.env"]
		package.preload["ward.fs"] = preload_orig["ward.fs"]

		package.loaded["ward.process"] = loaded_orig["ward.process"]
		package.loaded["ward.env"] = loaded_orig["ward.env"]
		package.loaded["ward.fs"] = loaded_orig["ward.fs"]
		for _, name in ipairs(MODULE_CANDIDATES) do
			package.loaded[name] = loaded_orig[name]
		end
	end

	local function load_module()
		local errs = {}
		for _, name in ipairs(MODULE_CANDIDATES) do
			local ok, mod = pcall(require, name)
			if ok and type(mod) == "table" then
				t:ok(type(mod.Jq) == "table", "module '" .. name .. "' did not return { Jq = ... }")
				return mod
			end
			errs[#errs + 1] = name .. ": " .. tostring(mod)
		end
		t:ok(false, "failed to require jq module. Tried:\n" .. table.concat(errs, "\n"))
	end

	local function last_cmd_obj() return calls.cmd[#calls.cmd] end

	t:before_all(function() install_mocks() end)

	t:after_all(function() restore_originals() end)

	t:before_each(function()
		reset_calls()
		env_ok = true
		fs_exists = {}
		fs_exec = {}
		for _, name in ipairs(MODULE_CANDIDATES) do
			package.loaded[name] = nil
		end
	end)

	t:test("eval builds argv with -- before filter", function()
		local mod = load_module()
		local Jq = mod.Jq

		Jq.eval(nil, "a.json", { raw_output = true })
		t:eq(calls.is_in_path[1], "jq")
		t:deep_eq(last_cmd_obj().argv, { "jq", "-r", "--", ".", "a.json" })
	end)

	t:test("eval emits vars deterministically and appends extra before filter", function()
		local mod = load_module()
		local Jq = mod.Jq

		Jq.eval(".x", nil, {
			arg = { z = "1", a = "2" },
			argjson = { b = "true" },
			rawfile = { f = "/tmp/data.txt" },
			extra = { "--unbuffered" },
		})
		t:deep_eq(last_cmd_obj().argv, {
			"jq",
			"--arg",
			"a",
			"2",
			"--arg",
			"z",
			"1",
			"--argjson",
			"b",
			"true",
			"--rawfile",
			"f",
			"/tmp/data.txt",
			"--unbuffered",
			"--",
			".x",
		})
	end)

	t:test("eval_stdin attaches stdin data", function()
		local mod = load_module()
		local Jq = mod.Jq

		local cmd = Jq.eval_stdin(".", '{"a": 1}', { compact_output = true })
		t:deep_eq(cmd.argv, { "jq", "-c", "--", "." })
		t:eq(cmd.stdin_data, '{"a": 1}')
	end)

	t:test("color_output and monochrome_output are mutually exclusive", function()
		local mod = load_module()
		local Jq = mod.Jq

		local ok = pcall(function() Jq.eval(".", nil, { color_output = true, monochrome_output = true }) end)
		t:falsy(ok)
	end)

	return t
end
