---@diagnostic disable: duplicate-set-field

-- Tinytest suite for zypper module (init.lua)

return function(tinytest)
	local t = tinytest.new({ name = "zypper" })
	local MODULE = "wardlib.app.zypper"

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

	local calls = { cmd = {}, is_in_path = {} }
	local env_ok = true

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
				is_exists = function() return false end,
				is_executable = function() return false end,
			}
		end
		package.loaded["ward.process"] = nil
		package.loaded["ward.env"] = nil
		package.loaded["ward.fs"] = nil
		package.loaded[MODULE] = nil
	end

	local function restore()
		package.preload["ward.process"] = preload_orig["ward.process"]
		package.preload["ward.env"] = preload_orig["ward.env"]
		package.preload["ward.fs"] = preload_orig["ward.fs"]
		package.loaded["ward.process"] = loaded_orig["ward.process"]
		package.loaded["ward.env"] = loaded_orig["ward.env"]
		package.loaded["ward.fs"] = loaded_orig["ward.fs"]
		package.loaded[MODULE] = loaded_orig[MODULE]
	end

	local function last_cmd() return calls.cmd[#calls.cmd] end

	t:before_all(install_mocks)
	t:after_all(restore)
	t:before_each(function()
		calls.cmd, calls.is_in_path = {}, {}
		env_ok = true
		package.loaded[MODULE] = nil
	end)

	t:test("install builds argv with common opts", function()
		local Zypper = require(MODULE).Zypper
		Zypper.install(
			{ "a", "b" },
			{ non_interactive = true, auto_agree_with_licenses = true, repos = { "oss", "update" } }
		)
		t:deep_eq(last_cmd().argv, {
			"zypper",
			"--non-interactive",
			"--auto-agree-with-licenses",
			"-r",
			"oss",
			"-r",
			"update",
			"install",
			"a",
			"b",
		})
	end)

	t:test("refresh builds argv", function()
		local Zypper = require(MODULE).Zypper
		Zypper.refresh({ quiet = true })
		t:deep_eq(last_cmd().argv, { "zypper", "-q", "refresh" })
	end)

	t:test("refresh and no_refresh are mutually exclusive", function()
		local Zypper = require(MODULE).Zypper
		local ok = pcall(function() Zypper.refresh({ refresh = true, no_refresh = true }) end)
		t:falsy(ok)
	end)

	return t
end
