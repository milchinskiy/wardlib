---@diagnostic disable: duplicate-set-field

-- Tinytest suite for git module (init.lua)
--
-- This suite mocks ward modules used by app.git:
--   * ward.process (cmd)
--   * ward.env     (is_in_path)
--   * ward.fs      (is_exists, is_executable)

return function(tinytest)
	local t = tinytest.new({ name = "git" })

	local MODULE_CANDIDATES = { "wardlib.app.git" }

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
				t:ok(type(mod.Git) == "table", "module '" .. name .. "' did not return { Git = ... }")
				return mod
			end
			errs[#errs + 1] = name .. ": " .. tostring(mod)
		end
		t:ok(false, "failed to require git module. Tried:\n" .. table.concat(errs, "\n"))
	end

	local function last_cmd() return calls.cmd[#calls.cmd] end

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

	-- -------------------------
	-- Tests
	-- -------------------------

	t:test("status supports opts.dir + flags", function()
		local mod = load_module()
		local Git = mod.Git

		Git.status({ dir = "/tmp/repo", short = true, branch = true })
		t:eq(calls.is_in_path[1], "git")
		t:deep_eq(last_cmd(), { "git", "-C", "/tmp/repo", "status", "-s", "-b" })
	end)

	t:test("root uses rev-parse --show-toplevel", function()
		local mod = load_module()
		local Git = mod.Git

		Git.root({ dir = "/tmp/repo" })
		t:deep_eq(last_cmd(), { "git", "-C", "/tmp/repo", "rev-parse", "--show-toplevel" })
	end)

	t:test("clone builds argv with depth + branch", function()
		local mod = load_module()
		local Git = mod.Git

		Git.clone("https://example.com/repo.git", "repo", { depth = 1, branch = "main" })
		t:deep_eq(last_cmd(), {
			"git",
			"clone",
			"--depth",
			"1",
			"--branch",
			"main",
			"https://example.com/repo.git",
			"repo",
		})
	end)

	t:test("push supports opts.dir and upstream", function()
		local mod = load_module()
		local Git = mod.Git

		Git.push("origin", "main", { dir = "/tmp/repo", upstream = true })
		t:deep_eq(last_cmd(), { "git", "-C", "/tmp/repo", "push", "-u", "origin", "main" })
	end)

	t:test("clone rejects flag-like branch", function()
		local mod = load_module()
		local Git = mod.Git

		local ok = pcall(function() Git.clone("https://example.com/repo.git", "repo", { branch = "--bad" }) end)
		t:falsy(ok)
	end)

	return t
end
