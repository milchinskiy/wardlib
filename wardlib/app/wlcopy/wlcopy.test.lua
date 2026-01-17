---@diagnostic disable: duplicate-set-field

-- Tinytest suite for clipboard module (init.lua)
--
-- This suite mocks ward modules used by app.clipboard:
--   * ward.process (cmd)
--   * ward.env     (is_in_path)
--   * ward.fs      (is_exists, is_executable)

return function(tinytest)
	local t = tinytest.new({ name = "wl-copy/wl-paste" })
	local MODULE_CANDIDATES = { "wardlib.app.wlcopy" }

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

	local function reset_calls()
		calls.cmd, calls.is_in_path, calls.is_exists, calls.is_executable = {}, {}, {}, {}
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
		for _, name in ipairs(MODULE_CANDIDATES) do
			package.loaded[name] = nil
		end
	end

	local function restore_originals()
		package.preload["ward.process"], package.preload["ward.env"], package.preload["ward.fs"] =
			preload_orig["ward.process"], preload_orig["ward.env"], preload_orig["ward.fs"]
		package.loaded["ward.process"], package.loaded["ward.env"], package.loaded["ward.fs"] =
			loaded_orig["ward.process"], loaded_orig["ward.env"], loaded_orig["ward.fs"]
		for _, name in ipairs(MODULE_CANDIDATES) do
			package.loaded[name] = loaded_orig[name]
		end
	end

	local function load_module()
		for _, name in ipairs(MODULE_CANDIDATES) do
			local ok, mod = pcall(require, name)
			if ok and type(mod) == "table" then
				t:ok(type(mod.Clipboard) == "table", "module '" .. name .. "' did not return { Clipboard = ... }")
				return mod
			end
		end
		t:ok(false, "failed to require clipboard module")
	end

	local function last_cmd() return calls.cmd[#calls.cmd] end

	t:before_all(install_mocks)
	t:after_all(restore_originals)
	t:before_each(function()
		reset_calls()
		env_ok = true
		fs_exists = {}
		fs_exec = {}
		for _, name in ipairs(MODULE_CANDIDATES) do
			package.loaded[name] = nil
		end
	end)

	t:test("paste builds argv with selection + no_newline", function()
		local mod = load_module()
		local Clipboard = mod.Clipboard

		Clipboard.paste({ selection = "primary", no_newline = true })
		t:eq(calls.is_in_path[1], "wl-paste")
		t:deep_eq(last_cmd(), { "wl-paste", "--primary", "--no-newline" })
	end)

	t:test("copy builds argv with type + paste-once", function()
		local mod = load_module()
		local Clipboard = mod.Clipboard

		Clipboard.copy({ type = "text/plain", paste_once = true })
		t:eq(calls.is_in_path[1], "wl-copy")
		t:deep_eq(last_cmd(), { "wl-copy", "--type", "text/plain", "--paste-once" })
	end)

	t:test("clear uses wl-copy --clear", function()
		local mod = load_module()
		local Clipboard = mod.Clipboard

		Clipboard.clear({ selection = "primary" })
		t:deep_eq(last_cmd(), { "wl-copy", "--primary", "--clear" })
	end)

	return t
end
