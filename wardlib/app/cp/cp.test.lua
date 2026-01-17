---@diagnostic disable: duplicate-set-field

-- Tinytest suite for cp module (init.lua)

return function(tinytest)
	local t = tinytest.new({ name = "cp" })
	local MODULE_CANDIDATES = { "wardlib.app.cp" }

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
	local function reset_calls()
		calls.cmd, calls.is_in_path, calls.is_exists, calls.is_executable = {}, {}, {}, {}
	end
	local env_ok, fs_exists, fs_exec = true, {}, {}

	local function install_mocks()
		package.preload["ward.process"] = function()
			return {
				cmd = function(...)
					local argv = { ... }
					local obj = { argv = argv }
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
				t:ok(type(mod.Cp) == "table")
				return mod
			end
			errs[#errs + 1] = name .. ": " .. tostring(mod)
		end
		t:ok(false, "failed to require cp module. Tried:\n" .. table.concat(errs, "\n"))
	end

	local function last_cmd() return calls.cmd[#calls.cmd] end

	t:before_all(install_mocks)
	t:after_all(restore_originals)
	t:before_each(function()
		reset_calls()
		env_ok, fs_exists, fs_exec = true, {}, {}
		for _, name in ipairs(MODULE_CANDIDATES) do
			package.loaded[name] = nil
		end
	end)

	t:test("copy builds argv with --", function()
		local Cp = load_module().Cp
		Cp.copy({ "a", "b" }, "dst", { recursive = true, verbose = true })
		t:eq(calls.is_in_path[1], "cp")
		t:deep_eq(last_cmd().argv, { "cp", "-r", "-v", "--", "a", "b", "dst" })
	end)

	t:test("into uses -t and omits dest", function()
		local Cp = load_module().Cp
		Cp.into("a", "dir", { parents = true })
		t:deep_eq(last_cmd().argv, { "cp", "--parents", "-t", "dir", "--", "a" })
	end)

	t:test("force and interactive are mutually exclusive", function()
		local Cp = load_module().Cp
		local ok = pcall(function() Cp.copy("a", "b", { force = true, interactive = true }) end)
		t:falsy(ok)
	end)

	return t
end
