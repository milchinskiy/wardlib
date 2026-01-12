---@diagnostic disable: duplicate-set-field

-- Tinytest suite for tools.ensure
--
-- Mocks:
--   * ward.env     (get, which, is_in_path)
--   * ward.fs      (is_exists, is_executable)
--   * ward.process (cmd -> :output())

return function(tinytest)
	local t = tinytest.new({ name = "tools.ensure" })

	local MODULE_CANDIDATES = { "tools.ensure" }

	local preload_orig = {
		["ward.env"] = package.preload["ward.env"],
		["ward.fs"] = package.preload["ward.fs"],
		["ward.process"] = package.preload["ward.process"],
	}
	local loaded_orig = {
		["ward.env"] = package.loaded["ward.env"],
		["ward.fs"] = package.loaded["ward.fs"],
		["ward.process"] = package.loaded["ward.process"],
	}

	local calls = {}
	local function reset_calls()
		calls = { cmd = {}, is_in_path = {}, which = {}, get = {}, fs_exists = {}, fs_exec = {} }
	end

	-- Mock state
	local env_vals = {}
	local which_map = {}
	local in_path_map = {}
	local fs_exists_map = {}
	local fs_exec_map = {}
	local cmd_output_map = {} -- key = table.concat(argv, "\0") -> { ok, stdout }

	local function install_mocks()
		package.preload["ward.env"] = function()
			return {
				get = function(k)
					table.insert(calls.get, k)
					return env_vals[k]
				end,
				which = function(name)
					table.insert(calls.which, name)
					return which_map[name]
				end,
				is_in_path = function(name_or_path)
					table.insert(calls.is_in_path, name_or_path)
					if in_path_map[name_or_path] ~= nil then
						return in_path_map[name_or_path]
					end
					return false
				end,
			}
		end

		package.preload["ward.fs"] = function()
			return {
				is_exists = function(p)
					table.insert(calls.fs_exists, p)
					return fs_exists_map[p] == true
				end,
				is_executable = function(p)
					table.insert(calls.fs_exec, p)
					return fs_exec_map[p] == true
				end,
			}
		end

		package.preload["ward.process"] = function()
			return {
				cmd = function(...)
					local argv = { ... }
					table.insert(calls.cmd, argv)
					local key = table.concat(argv, "\0")
					local out = cmd_output_map[key] or { ok = true, stdout = "" }
					return {
						output = function()
							return { ok = out.ok, stdout = out.stdout }
						end,
					}
				end,
			}
		end

		package.loaded["ward.env"] = nil
		package.loaded["ward.fs"] = nil
		package.loaded["ward.process"] = nil
		for _, name in ipairs(MODULE_CANDIDATES) do
			package.loaded[name] = nil
		end
	end

	local function restore_originals()
		package.preload["ward.env"] = preload_orig["ward.env"]
		package.preload["ward.fs"] = preload_orig["ward.fs"]
		package.preload["ward.process"] = preload_orig["ward.process"]

		package.loaded["ward.env"] = loaded_orig["ward.env"]
		package.loaded["ward.fs"] = loaded_orig["ward.fs"]
		package.loaded["ward.process"] = loaded_orig["ward.process"]
		for _, name in ipairs(MODULE_CANDIDATES) do
			package.loaded[name] = nil
		end
	end

	local function mod()
		return require("tools.ensure")
	end

	-- --- tests ---

	t:test("bin(name) returns resolved path when in PATH", function()
		reset_calls()
		env_vals = {}
		which_map = { git = "/usr/bin/git" }
		in_path_map = { git = true }
		install_mocks()

		local ensure = mod()
		local p = ensure.bin("git")
		t:eq(p, "/usr/bin/git")
		restore_originals()
	end)

	t:test("bin(path) validates existence + executability", function()
		reset_calls()
		fs_exists_map = { ["/bin/echo"] = true }
		fs_exec_map = { ["/bin/echo"] = true }
		install_mocks()

		local ensure = mod()
		local p = ensure.bin("/bin/echo")
		t:eq(p, "/bin/echo")
		restore_originals()
	end)

	t:test("bin(name) errors when missing", function()
		reset_calls()
		in_path_map = { jq = false }
		install_mocks()

		local ensure = mod()
		local ok, err = pcall(function()
			ensure.bin("jq")
		end)
		t:eq(ok, false)
		t:contains(err, "not found in PATH")
		t:contains(err, "jq")
		restore_originals()
	end)

	t:test("env(key) returns value", function()
		reset_calls()
		env_vals = { TOKEN = "abc" }
		install_mocks()

		local ensure = mod()
		local v = ensure.env("TOKEN")
		t:eq(v, "abc")
		restore_originals()
	end)

	t:test("env(keys) returns map", function()
		reset_calls()
		env_vals = { A = "1", B = "2" }
		install_mocks()

		local ensure = mod()
		local m = ensure.env({ "A", "B" })
		t:eq(m.A, "1")
		t:eq(m.B, "2")
		restore_originals()
	end)

	t:test("root() passes when id -u == 0", function()
		reset_calls()
		which_map = { id = "/usr/bin/id" }
		cmd_output_map = {
			["/usr/bin/id\0-u"] = { ok = true, stdout = "0\n" },
		}
		install_mocks()

		local ensure = mod()
		local ok = ensure.root()
		t:eq(ok, true)
		restore_originals()
	end)

	t:test("root() errors when id -u != 0", function()
		reset_calls()
		which_map = { id = "/usr/bin/id" }
		cmd_output_map = {
			["/usr/bin/id\0-u"] = { ok = true, stdout = "1000\n" },
		}
		install_mocks()

		local ensure = mod()
		local ok, err = pcall(function()
			ensure.root({ allow_sudo_hint = false })
		end)
		t:eq(ok, false)
		t:contains(err, "root privileges required")
		restore_originals()
	end)

	t:test("os(linux) passes when uname -s returns Linux", function()
		reset_calls()
		which_map = { uname = "/bin/uname" }
		cmd_output_map = {
			["/bin/uname\0-s"] = { ok = true, stdout = "Linux\n" },
		}
		install_mocks()

		local ensure = mod()
		local v = ensure.os("linux")
		t:eq(v, "linux")
		restore_originals()
	end)

	t:test("os(unix) accepts linux/darwin/etc", function()
		reset_calls()
		which_map = { uname = "/bin/uname" }
		cmd_output_map = {
			["/bin/uname\0-s"] = { ok = true, stdout = "Linux\n" },
		}
		install_mocks()

		local ensure = mod()
		local v = ensure.os("unix")
		t:eq(v, "linux")
		restore_originals()
	end)

	return t
end
