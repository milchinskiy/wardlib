-- Tinytest suite for dunst module (init.lua)
-- NOTE: deliberately complicated for demonstration
--
-- This suite mocks ward modules used by dunst:
--   * ward.process (cmd)
--   * ward.env     (is_in_path)
--   * ward.fs      (is_exists, is_executable)
--
-- It asserts that the produced argv is correct and flags are in the expected order.

return function(tinytest)
	local t = tinytest.new({ name = "dunst" })

	-- Runner is expected to execute this file by path,
	-- but we still require the module under test.
	local MODULE_CANDIDATES = { "wardlib.app.dunst" }

	-- Save originals so we do not leak mocks into other suites.
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

	-- Call recorder
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

	-- Mock controls
	local env_ok = true
	local fs_exists = {}
	local fs_exec = {}

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

		-- Force reload with mocks
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
				t:ok(type(mod.Dunst) == "table", "module '" .. name .. "' did not return { Dunst = ... }")
				return mod
			end
			errs[#errs + 1] = name .. ": " .. tostring(mod)
		end
		t:ok(false, "failed to require dunst module. Tried:\n" .. table.concat(errs, "\n"))
	end

	local function last_cmd()
		return calls.cmd[#calls.cmd]
	end

	t:before_all(function()
		install_mocks()
	end)

	t:after_all(function()
		restore_originals()
	end)

	t:before_each(function()
		reset_calls()
		env_ok = true
		fs_exists = {}
		fs_exec = {}
		for _, name in ipairs(MODULE_CANDIDATES) do
			package.loaded[name] = nil
		end
	end)

	-- -------------------------
	-- Tests
	-- -------------------------

	t:test("notify builds minimal args and validates PATH bin", function()
		local mod = load_module()
		local Dunst = mod.Dunst

		Dunst.bin = "dunstify"
		Dunst.notify("hello")

		t:eq(#calls.is_in_path, 1)
		t:eq(calls.is_in_path[1], "dunstify")
		t:eq(#calls.is_exists, 0)
		t:eq(#calls.is_executable, 0)

		local argv = last_cmd()
		t:deep_eq(argv, { "dunstify", "hello" })
	end)

	t:test("notify rejects empty summary", function()
		local mod = load_module()
		local Dunst = mod.Dunst

		local ok = pcall(function()
			Dunst.notify("")
		end)
		t:falsy(ok, "expected notify to fail on empty summary")
	end)

	t:test("notify rejects unknown urgency", function()
		local mod = load_module()
		local Dunst = mod.Dunst

		local ok, err = pcall(function()
			Dunst.notify("x", { urgency = "urgent" })
		end)
		t:falsy(ok)
		t:match(tostring(err), "Unknown urgency")
	end)

	t:test("notify builds full arg list in expected order", function()
		local mod = load_module()
		local Dunst = mod.Dunst

		Dunst.bin = "dunstify"
		Dunst.notify("sum", {
			body = "body",
			app_name = "app",
			urgency = "critical",
			timeout = 5000,
			hints = "int:value:1",
			action = "default,Open",
			icon = "icon.png",
			raw_icon = "/tmp/icon.raw",
			category = "cat",
			replaceId = 42,
			block = true,
			printId = true,
		})

		local argv = last_cmd()
		t:deep_eq(argv, {
			"dunstify",
			"-a",
			"app",
			"-u",
			"critical",
			"-t",
			"5000",
			"-h",
			"int:value:1",
			"-A",
			"default,Open",
			"-i",
			"icon.png",
			"-I",
			"/tmp/icon.raw",
			"-c",
			"cat",
			"-r",
			"42",
			"-b",
			"-p",
			"sum",
			"body",
		})
	end)

	t:test("validate_bin uses fs checks for path bins", function()
		local mod = load_module()
		local Dunst = mod.Dunst

		local bin = "/usr/bin/dunstify"
		Dunst.bin = bin
		fs_exists[bin] = true
		fs_exec[bin] = true

		Dunst.notify("hi")

		t:eq(#calls.is_in_path, 0)
		t:eq(#calls.is_exists, 1)
		t:eq(calls.is_exists[1], bin)
		t:eq(#calls.is_executable, 1)
		t:eq(calls.is_executable[1], bin)

		local argv = last_cmd()
		t:deep_eq(argv, { bin, "hi" })
	end)

	t:test("close calls -C with stringified id", function()
		local mod = load_module()
		local Dunst = mod.Dunst
		Dunst.bin = "dunstify"

		Dunst.close(7)

		local argv = last_cmd()
		t:deep_eq(argv, { "dunstify", "-C", "7" })
	end)

	t:test("capabilities calls --capabilities", function()
		local mod = load_module()
		local Dunst = mod.Dunst
		Dunst.bin = "dunstify"

		Dunst.capabilities()

		local argv = last_cmd()
		t:deep_eq(argv, { "dunstify", "--capabilities" })
	end)

	t:test("serverInfo calls --serverinfo", function()
		local mod = load_module()
		local Dunst = mod.Dunst
		Dunst.bin = "dunstify"

		Dunst.serverInfo()

		local argv = last_cmd()
		t:deep_eq(argv, { "dunstify", "--serverinfo" })
	end)

	return t
end
