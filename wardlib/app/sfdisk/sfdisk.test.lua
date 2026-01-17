---@diagnostic disable: duplicate-set-field

-- Tinytest suite for sfdisk module (init.lua)
--
-- Mocks ward modules used by app.sfdisk:
--   * ward.process (cmd) with pipeline support (`|` => __bor)
--   * ward.env     (is_in_path)
--   * ward.fs      (is_exists, is_executable)

return function(tinytest)
	local t = tinytest.new({ name = "sfdisk" })

	local MODULE_CANDIDATES = { "wardlib.app.sfdisk" }

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
			local Cmd = {}
			Cmd.__index = Cmd

			function Cmd:new(argv) return setmetatable({ argv = argv }, Cmd) end

			function Cmd:__bor(rhs) return { kind = "pipe", left = self, right = rhs } end

			return {
				cmd = function(...)
					local argv = { ... }
					table.insert(calls.cmd, argv)
					return Cmd:new(argv)
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
				t:ok(type(mod.Sfdisk) == "table", "module '" .. name .. "' did not return { Sfdisk = ... }")
				return mod
			end
			errs[#errs + 1] = name .. ": " .. tostring(mod)
		end
	end

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

	t:test("Sfdisk.script encodes structured table", function()
		local mod = load_module()

		local script = mod.Sfdisk.script({
			label = "gpt",
			unit = "sectors",
			partitions = {
				{ start = 2048, size = "512M", type = "U" },
				{ start = 1050624, size = "20G", type = "8300", bootable = true },
			},
		})

		local expected = table.concat({
			"label: gpt",
			"unit: sectors",
			"",
			"start=2048, size=512M, type=U",
			"start=1050624, size=20G, type=8300, bootable",
			"",
		}, "\n")

		t:eq(script, expected)
	end)

	t:test("Sfdisk.apply builds printf | sfdisk pipeline", function()
		local mod = load_module()

		local pipe = mod.Sfdisk.apply("/dev/sda", {
			label = "gpt",
			partitions = {
				{ start = 2048, size = "1G", type = "U" },
			},
		}, { force = true })

		t:eq(#calls.cmd, 2)

		local expected_script = table.concat({
			"label: gpt",
			"",
			"start=2048, size=1G, type=U",
			"",
		}, "\n")

		t:deep_eq(calls.cmd[1], { "printf", "%s", expected_script })
		t:deep_eq(calls.cmd[2], { "sfdisk", "--force", "/dev/sda" })

		t:eq(pipe.kind, "pipe")
		t:deep_eq(pipe.left.argv, { "printf", "%s", expected_script })
		t:deep_eq(pipe.right.argv, { "sfdisk", "--force", "/dev/sda" })
	end)

	return t
end
