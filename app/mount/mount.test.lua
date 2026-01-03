---@diagnostic disable: duplicate-set-field

-- Tinytest suite for mount module (init.lua)
--
-- This suite mocks ward modules used by app.mount:
--   * ward.process (cmd)
--   * ward.env     (is_in_path)
--   * ward.fs      (is_exists, is_executable)

return function(tinytest)
	local t = tinytest.new({ name = "mount" })

	local MODULE_CANDIDATES = { "app.mount" }

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
					return false
				end,
				is_executable = function(path)
					table.insert(calls.is_executable, path)
					return false
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
				t:ok(type(mod.Mount) == "table", "module '" .. name .. "' did not return { Mount = ... }")
				return mod
			end
			errs[#errs + 1] = name .. ": " .. tostring(mod)
		end
		t:ok(false, "failed to require mount module. Tried:\\n" .. table.concat(errs, "\\n"))
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
		for _, name in ipairs(MODULE_CANDIDATES) do
			package.loaded[name] = nil
		end
	end)

	-- -------------------------
	-- Tests
	-- -------------------------

	t:test("mount with fstype + options + readonly", function()
		local mod = load_module()
		mod.Mount.mount("/dev/sda1", "/mnt/data", { fstype = "ext4", options = { "noatime" }, readonly = true })
		t:deep_eq(last_cmd(), { "mount", "-t", "ext4", "-o", "noatime,ro", "/dev/sda1", "/mnt/data" })
	end)

	t:test("mount bind", function()
		local mod = load_module()
		mod.Mount.mount("/src", "/dst", { bind = true })
		t:deep_eq(last_cmd(), { "mount", "--bind", "/src", "/dst" })
	end)

	t:test("umount supports flags", function()
		local mod = load_module()
		mod.Mount.umount("/mnt/data", { lazy = true, verbose = true })
		t:deep_eq(last_cmd(), { "umount", "-l", "-v", "/mnt/data" })
	end)

	t:test("rejects flag-like target", function()
		local mod = load_module()
		local ok = pcall(function()
			mod.Mount.umount("--bad")
		end)
		t:falsy(ok)
	end)

	return t
end
