---@diagnostic disable: duplicate-set-field

-- Tinytest suite for qemu module (init.lua)
--
-- Mocks ward modules used by app.qemu:
--   * ward.process (cmd)
--   * ward.env     (is_in_path, which)
--   * ward.fs      (is_exists, is_executable)

return function(tinytest)
	local t = tinytest.new({ name = "qemu" })

	local MODULE_CANDIDATES = { "wardlib.app.qemu" }

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
		which = {},
		is_exists = {},
		is_executable = {},
	}

	local function reset_calls()
		calls.cmd = {}
		calls.is_in_path = {}
		calls.which = {}
		calls.is_exists = {}
		calls.is_executable = {}
	end

	local env_in_path = {}
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
					return env_in_path[bin] == true
				end,
				which = function(bin)
					table.insert(calls.which, bin)
					-- Return a stable pseudo-path for tests
					return "/usr/bin/" .. tostring(bin)
				end,
				get = function() return nil end,
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
				t:ok(type(mod.Qemu) == "table", "module '" .. name .. "' did not return { Qemu = ... }")
				return mod
			end
			errs[#errs + 1] = name .. ": " .. tostring(mod)
		end
		t:ok(false, "failed to require qemu module. Tried:\n" .. table.concat(errs, "\\n"))
	end

	local function last_cmd() return calls.cmd[#calls.cmd] end

	t:before_all(install_mocks)
	t:after_all(restore_originals)

	t:before_each(function()
		reset_calls()
		env_in_path = {}
		fs_exists = {}
		fs_exec = {}
		for _, name in ipairs(MODULE_CANDIDATES) do
			package.loaded[name] = nil
		end
	end)

	-- -------------------------
	-- Tests
	-- -------------------------

	t:test("system: builds qemu-system-<arch> with structured specs", function()
		env_in_path["qemu-system-x86_64"] = true

		local mod = load_module()
		local Qemu = mod.Qemu

		Qemu.system("x86_64", {
			memory = "1G",
			smp = 2,
			nographic = true,
			netdev = {
				{ type = "user", id = "net0", hostfwd = Qemu.hostfwd({ hostport = 2222, guestport = 22 }) },
			},
			device = {
				{ driver = "virtio-net-pci", netdev = "net0" },
			},
			drive = {
				{
					file = "disk.qcow2",
					format = "qcow2",
					["if"] = "virtio",
					-- or
					-- if_ = "virtio",
				},
			},
		})

		t:deep_eq(last_cmd(), {
			"qemu-system-x86_64",
			"-smp",
			"2",
			"-m",
			"1G",
			"-nographic",
			"-netdev",
			"user,hostfwd=tcp::2222-:22,id=net0",
			"-device",
			"virtio-net-pci,netdev=net0",
			"-drive",
			"file=disk.qcow2,format=qcow2,if=virtio",
		})
	end)

	t:test("system: convenience helpers pick the correct binary", function()
		env_in_path["qemu-system-aarch64"] = true

		local mod = load_module()
		local Qemu = mod.Qemu

		Qemu.system_aarch64({ memory = 512 })
		t:deep_eq(last_cmd(), { "qemu-system-aarch64", "-m", "512" })
	end)

	t:test("img: create qcow2 with -f and -o", function()
		env_in_path["qemu-img"] = true

		local mod = load_module()
		local Qemu = mod.Qemu

		Qemu.img_create("disk.qcow2", "10G", {
			format = "qcow2",
			options = { cluster_size = "2M", preallocation = "metadata" },
		})

		t:deep_eq(last_cmd(), {
			"qemu-img",
			"create",
			"-f",
			"qcow2",
			"-o",
			"cluster_size=2M,preallocation=metadata",
			"disk.qcow2",
			"10G",
		})
	end)

	t:test("nbd: connect and disconnect", function()
		env_in_path["qemu-nbd"] = true

		local mod = load_module()
		local Qemu = mod.Qemu

		Qemu.nbd_connect("/dev/nbd0", "disk.qcow2", { format = "qcow2" })
		t:deep_eq(last_cmd(), { "qemu-nbd", "-c", "/dev/nbd0", "-f", "qcow2", "disk.qcow2" })

		Qemu.nbd_disconnect("/dev/nbd0")
		t:deep_eq(last_cmd(), { "qemu-nbd", "-d", "/dev/nbd0" })
	end)

	return t
end
