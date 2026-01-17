---@diagnostic disable: duplicate-set-field

-- Tinytest suite for ls module (init.lua)

return function(tinytest)
	local t = tinytest.new({ name = "ls" })
	local MODULE_CANDIDATES = { "wardlib.app.ls" }

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
					local obj = { argv = { ... } }
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
		local ok, mod = pcall(require, "wardlib.app.ls")
		t:ok(ok)
		t:ok(type(mod) == "table" and type(mod.Ls) == "table")
		return mod
	end

	local function last_cmd() return calls.cmd[#calls.cmd] end

	t:before_all(install_mocks)
	t:after_all(restore_originals)
	t:before_each(function()
		reset_calls()
		env_ok, fs_exists, fs_exec = true, {}, {}
		package.loaded["app.ls"] = nil
	end)

	t:test("list defaults to '.' and uses --", function()
		local Ls = load_module().Ls
		Ls.list(nil, { all = true, long = true })
		t:eq(calls.is_in_path[1], "ls")
		t:deep_eq(last_cmd().argv, { "ls", "-a", "-l", "--", "." })
	end)

	t:test("sort exclusivity", function()
		local Ls = load_module().Ls
		local ok = pcall(function() Ls.list(".", { sort_time = true, sort_size = true }) end)
		t:falsy(ok)
	end)

	return t
end
