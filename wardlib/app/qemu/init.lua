---@diagnostic disable: undefined-doc-name

-- qemu wrapper module
--
-- QEMU's CLI surface is huge. We model common flags and the recurring
-- comma-list spec patterns (-netdev, -device, ...). For advanced flags,
-- all wrappers accept `opts.extra`.

local _cmd = require("ward.process")
local args_util = require("wardlib.util.args")
local ensure = require("wardlib.tools.ensure")
local validate = require("wardlib.util.validate")

-- -----------------------------------------------------------------------------
-- Internal helpers
-- -----------------------------------------------------------------------------

local function bool_onoff(v)
	if v == true then return "on" end
	if v == false then return "off" end
	return tostring(v)
end

local function is_array(t) return args_util.is_array_strict(t) end

---Encode a QEMU "comma list" spec.
---
---Accepted forms:
---* string: returned as-is
---* string[]: joined with commas
---* map table: stable-sorted k=v, boolean values -> on/off
---@param spec any
---@param label string
---@return string
local function encode_kv(spec, label)
	label = label or "spec"
	if type(spec) == "string" then
		validate.non_empty_string(spec, label)
		return spec
	end
	assert(type(spec) == "table", label .. " must be a string, string[], or table")

	if is_array(spec) then
		assert(#spec > 0, label .. " list must be non-empty")
		local parts = {}
		for _, s in ipairs(spec) do
			validate.non_empty_string(s, label)
			parts[#parts + 1] = tostring(s)
		end
		return table.concat(parts, ",")
	end

	local parts = {}
	for _, k in ipairs(args_util.sorted_keys(spec)) do
		validate.non_empty_string(k, label .. " key")
		local v = spec[k]
		assert(v ~= nil, label .. "['" .. k .. "'] is nil")
		parts[#parts + 1] = k .. "=" .. bool_onoff(v)
	end
	return table.concat(parts, ",")
end

---Encode a QEMU spec with a leading token (e.g. -device DRIVER,...).
---@param spec any
---@param cfg { head_key: string, label: string, aliases?: table }
---@return string
local function encode_headed(spec, cfg)
	cfg = cfg or {}
	local head_key = cfg.head_key
	local label = cfg.label or "spec"
	assert(type(head_key) == "string" and #head_key > 0, "encode_headed: head_key is required")

	if type(spec) == "string" then
		validate.non_empty_string(spec, label)
		return spec
	end
	assert(type(spec) == "table", label .. " must be string or table")

	local head = spec[head_key]
	assert(type(head) == "string" and #head > 0, label .. "." .. head_key .. " must be a non-empty string")

	local rest = {}
	for _, k in ipairs(args_util.sorted_keys(spec)) do
		if k ~= head_key then
			local out_k = k
			if cfg.aliases and cfg.aliases[k] then out_k = cfg.aliases[k] end
			validate.non_empty_string(out_k, label .. " key")
			local v = spec[k]
			assert(v ~= nil, label .. "['" .. k .. "'] is nil")
			rest[#rest + 1] = out_k .. "=" .. bool_onoff(v)
		end
	end

	if #rest == 0 then return head end
	return head .. "," .. table.concat(rest, ",")
end

local function validate_scalar_or_string(v, label)
	if type(v) == "number" then return end
	validate.non_empty_string(v, label)
end

local function normalize_string_or_array(v, label) return args_util.normalize_string_or_array(v, label) end

local function normalize_list(v, label)
	if v == nil then return {} end
	assert(type(v) == "table", label .. " must be a table")
	return v
end

local function append_specs(args, flag, list, encoder)
	for _, spec in ipairs(list or {}) do
		local s = encoder(spec)
		validate.non_empty_string(s, flag .. " spec")
		args[#args + 1] = flag
		args[#args + 1] = s
	end
end

-- -----------------------------------------------------------------------------
-- Public API
-- -----------------------------------------------------------------------------

---@class Qemu
---@field system_prefix string
---@field img_bin string
---@field nbd_bin string
---@field storage_daemon_bin string
---@field hostfwd fun(spec: table): string
---@field drive fun(spec: string|table): string
---@field netdev fun(spec: string|table): string
---@field device fun(spec: string|table): string
---@field chardev fun(spec: string|table): string
---@field fsdev fun(spec: string|table): string
---@field object fun(spec: string|table): string
---@field kv fun(spec: string|string[]|table): string
---@field system fun(arch: string, opts: QemuSystemOpts|nil): ward.Cmd
---@field system_x86_64 fun(opts: QemuSystemOpts|nil): ward.Cmd
---@field system_i386 fun(opts: QemuSystemOpts|nil): ward.Cmd
---@field system_aarch64 fun(opts: QemuSystemOpts|nil): ward.Cmd
---@field system_arm fun(opts: QemuSystemOpts|nil): ward.Cmd
---@field system_riscv64 fun(opts: QemuSystemOpts|nil): ward.Cmd
---@field system_ppc64 fun(opts: QemuSystemOpts|nil): ward.Cmd
---@field system_s390x fun(opts: QemuSystemOpts|nil): ward.Cmd
---@field img_create fun(filename: string, size: string|number|nil, opts: QemuImgCreateOpts|nil): ward.Cmd
---@field img_info fun(filename: string, opts: QemuImgInfoOpts|nil): ward.Cmd
---@field img_convert fun(src: string|string[], dst: string, opts: QemuImgConvertOpts|nil): ward.Cmd
---@field img_resize fun(filename: string, size: string|number, opts: QemuImgResizeOpts|nil): ward.Cmd
---@field img_snapshot_list fun(filename: string, opts: QemuImgSnapshotOpts|nil): ward.Cmd
---@field img_snapshot_create fun(filename: string, name: string, opts: QemuImgSnapshotOpts|nil): ward.Cmd
---@field img_snapshot_apply fun(filename: string, name: string, opts: QemuImgSnapshotOpts|nil): ward.Cmd
---@field img_snapshot_delete fun(filename: string, name: string, opts: QemuImgSnapshotOpts|nil): ward.Cmd
---@field nbd_serve fun(filename_or_image_opts: string, opts: QemuNbdOpts|nil): ward.Cmd
---@field nbd_connect fun(dev: string, filename_or_image_opts: string, opts: QemuNbdOpts|nil): ward.Cmd
---@field nbd_disconnect fun(dev: string, opts: QemuNbdDisconnectOpts|nil): ward.Cmd
---@field nbd_list fun(opts: QemuNbdListOpts|nil): ward.Cmd
---@field storage_daemon fun(opts: QemuStorageDaemonOpts|nil): ward.Cmd
local Qemu = {
	system_prefix = "qemu-system-",
	img_bin = "qemu-img",
	nbd_bin = "qemu-nbd",
	storage_daemon_bin = "qemu-storage-daemon",
}

-- ---------------------------
-- Comma-list helpers
-- ---------------------------

---Build a "hostfwd=" string for -netdev user.
---@param spec { proto?: string, hostaddr?: string, hostport: number, guestaddr?: string, guestport: number }
---@return string
function Qemu.hostfwd(spec)
	assert(type(spec) == "table", "hostfwd spec must be a table")
	local proto = spec.proto or "tcp"
	validate.non_empty_string(proto, "proto")
	validate.integer_non_negative(spec.hostport, "hostport")
	validate.integer_non_negative(spec.guestport, "guestport")

	local hostaddr = spec.hostaddr or ""
	local guestaddr = spec.guestaddr or ""
	if hostaddr ~= "" then validate.non_empty_string(hostaddr, "hostaddr") end
	if guestaddr ~= "" then validate.non_empty_string(guestaddr, "guestaddr") end

	return string.format("%s:%s:%d-%s:%d", proto, hostaddr, spec.hostport, guestaddr, spec.guestport)
end

---Encode a -drive spec.
---
---For tables, this produces the canonical key/value form:
---`file=<path>,if=<...>,format=<...>,...`.
---Alias: `if_` -> `if`.
---@param spec string|table
---@return string
function Qemu.drive(spec)
	if type(spec) == "string" then
		validate.non_empty_string(spec, "drive")
		return spec
	end
	assert(type(spec) == "table", "drive must be a string or table")
	assert(type(spec.file) == "string" and #spec.file > 0, "drive.file must be a non-empty string")
	if spec.if_ ~= nil and spec["if"] == nil then
		spec["if"] = spec.if_
		spec.if_ = nil
	end
	return encode_kv(spec, "drive")
end

---Encode a -netdev spec. Required key: `type`.
---@param spec string|table
---@return string
function Qemu.netdev(spec) return encode_headed(spec, { head_key = "type", label = "netdev" }) end

---Encode a -device spec. Required key: `driver`.
---@param spec string|table
---@return string
function Qemu.device(spec) return encode_headed(spec, { head_key = "driver", label = "device" }) end

---Encode a -chardev spec. Required key: `backend`.
---@param spec string|table
---@return string
function Qemu.chardev(spec) return encode_headed(spec, { head_key = "backend", label = "chardev" }) end

---Encode a -fsdev spec. Required key: `driver`.
---@param spec string|table
---@return string
function Qemu.fsdev(spec) return encode_headed(spec, { head_key = "driver", label = "fsdev" }) end

---Encode a -object spec. Required key: `type`.
---@param spec string|table
---@return string
function Qemu.object(spec) return encode_headed(spec, { head_key = "type", label = "object" }) end

---Generic encoder for "k=v,k2=v2" style specs.
---@param spec string|string[]|table
---@return string
function Qemu.kv(spec) return encode_kv(spec, "kv") end

-- -----------------------------------------------------------------------------
-- qemu-system-<arch>
-- -----------------------------------------------------------------------------

---@class QemuSystemOpts
---@field bin string? Override binary (name or absolute path). If unset, uses `qemu-system-<arch>`.
---@field name string?
---@field uuid string?
---@field machine string? `-machine <val>`
---@field accel string|string[]? `-accel <val>` (repeatable)
---@field cpu string? `-cpu <val>`
---@field smp number|string? `-smp <n>` or `-smp <spec>`
---@field memory number|string? `-m <n>` (e.g. 2048 or "2G")
---@field bios string? `-bios <file>`
---@field kernel string? `-kernel <file>`
---@field initrd string? `-initrd <file>`
---@field append string? `-append <cmdline>`
---@field boot string? `-boot <spec>`
---@field cdrom string? `-cdrom <file>`
---@field snapshot boolean? `-snapshot`
---@field nographic boolean? `-nographic`
---@field display string? `-display <type>`
---@field serial string|string[]? `-serial <dev>` (repeatable)
---@field monitor string|string[]? `-monitor <dev>` (repeatable)
---@field qmp string|string[]? `-qmp <dev>` (repeatable)
---@field daemonize boolean? `-daemonize`
---@field pidfile string? `-pidfile <path>`
---@field gdb string? `-gdb <dev>`
---@field start_paused boolean? `-S`
---@field rtc string? `-rtc <spec>`
---@field clock string? `-clock <spec>`
---@field object (string|table)[]? `-object <spec>`
---@field chardev (string|table)[]? `-chardev <spec>`
---@field fsdev (string|table)[]? `-fsdev <spec>`
---@field netdev (string|table)[]? `-netdev <spec>`
---@field device (string|table)[]? `-device <spec>`
---@field drive (string|table)[]? `-drive <spec>`
---@field global string|string[]? `-global <spec>`
---@field extra string[]? Extra args appended after modeled options, before positional images
---@field images string|string[]? Positional disk images appended last

---@param arch string
---@param opts QemuSystemOpts|nil
---@return string
local function choose_system_bin(arch, opts)
	args_util.token(arch, "arch")
	opts = opts or {}
	if opts.bin ~= nil then
		ensure.bin(opts.bin, { label = "qemu-system binary" })
		return opts.bin
	end
	local bin = Qemu.system_prefix .. arch
	ensure.bin(bin, { label = "qemu-system binary" })
	return bin
end

local function apply_system_opts(args, opts)
	opts = opts or {}
	local p = args_util.parser(args, opts)
	p:value_string("name", "-name")
	p:value_string("uuid", "-uuid")
	p:value_string("machine", "-machine")
	p:repeatable("accel", "-accel", { validate = validate.non_empty_string })
	p:value_string("cpu", "-cpu")
	p:value("smp", "-smp", { label = "smp", validate = validate_scalar_or_string })
	p:value("memory", "-m", { label = "memory", validate = validate_scalar_or_string })
	p:value_string("bios", "-bios")
	p:value_string("kernel", "-kernel")
	p:value_string("initrd", "-initrd")
	p:value_string("append", "-append")
	p:value_string("boot", "-boot")
	p:value_string("cdrom", "-cdrom")
	p:flag("snapshot", "-snapshot")
	p:flag("nographic", "-nographic")
	p:value_string("display", "-display")
	p:repeatable("serial", "-serial", { validate = validate.non_empty_string })
	p:repeatable("monitor", "-monitor", { validate = validate.non_empty_string })
	p:repeatable("qmp", "-qmp", { validate = validate.non_empty_string })
	p:flag("daemonize", "-daemonize")
	p:value_string("pidfile", "-pidfile")
	p:value_string("gdb", "-gdb")
	p:flag("start_paused", "-S")
	p:value_string("rtc", "-rtc")
	p:value_string("clock", "-clock")
	p:repeatable("global", "-global", { validate = validate.non_empty_string })

	append_specs(args, "-object", normalize_list(opts.object, "object"), Qemu.object)
	append_specs(args, "-chardev", normalize_list(opts.chardev, "chardev"), Qemu.chardev)
	append_specs(args, "-fsdev", normalize_list(opts.fsdev, "fsdev"), Qemu.fsdev)
	append_specs(args, "-netdev", normalize_list(opts.netdev, "netdev"), Qemu.netdev)
	append_specs(args, "-device", normalize_list(opts.device, "device"), Qemu.device)
	append_specs(args, "-drive", normalize_list(opts.drive, "drive"), Qemu.drive)

	-- opts.extra
	p:extra()
end

---@param arch string
---@param opts QemuSystemOpts|nil
---@return ward.Cmd
function Qemu.system(arch, opts)
	local bin = choose_system_bin(arch, opts)
	local args = { bin }
	apply_system_opts(args, opts)

	opts = opts or {}
	if opts.images ~= nil then
		local imgs = normalize_string_or_array(opts.images, "images")
		for _, img in ipairs(imgs) do
			validate.non_empty_string(img, "image")
			args[#args + 1] = img
		end
	end

	return _cmd.cmd(table.unpack(args))
end

function Qemu.system_x86_64(opts) return Qemu.system("x86_64", opts) end
function Qemu.system_i386(opts) return Qemu.system("i386", opts) end
function Qemu.system_aarch64(opts) return Qemu.system("aarch64", opts) end
function Qemu.system_arm(opts) return Qemu.system("arm", opts) end
function Qemu.system_riscv64(opts) return Qemu.system("riscv64", opts) end
function Qemu.system_ppc64(opts) return Qemu.system("ppc64", opts) end
function Qemu.system_s390x(opts) return Qemu.system("s390x", opts) end

-- -----------------------------------------------------------------------------
-- qemu-img
-- -----------------------------------------------------------------------------

---@class QemuImgCreateOpts
---@field bin string? Override qemu-img binary
---@field format string? `-f <fmt>`
---@field options string|string[]|table? `-o <opts>` (comma list)
---@field quiet boolean? `-q`
---@field extra string[]? Extra args

---@class QemuImgInfoOpts
---@field bin string? Override qemu-img binary
---@field format string? `-f <fmt>`
---@field output string? `--output=<format>` (e.g. "json")
---@field extra string[]? Extra args

---@class QemuImgConvertOpts
---@field bin string? Override qemu-img binary
---@field input_format string? `-f <fmt>`
---@field output_format string? `-O <fmt>`
---@field output_options string|string[]|table? `-o <opts>` (comma list)
---@field backing_file string? `-B <file>`
---@field snapshot string? `-s <name>`
---@field compress boolean? `-c`
---@field progress boolean? `-p`
---@field quiet boolean? `-q`
---@field unsafe boolean? `-U`
---@field image_opts boolean? `--image-opts`
---@field target_image_opts boolean? `--target-image-opts`
---@field extra string[]? Extra args

---@class QemuImgResizeOpts
---@field bin string? Override qemu-img binary
---@field format string? `-f <fmt>`
---@field preallocation string? `--preallocation=<mode>`
---@field quiet boolean? `-q`
---@field extra string[]? Extra args

---@class QemuImgSnapshotOpts
---@field bin string? Override qemu-img binary
---@field extra string[]? Extra args

local function choose_img_bin(opts)
	opts = opts or {}
	local bin = opts.bin or Qemu.img_bin
	ensure.bin(bin, { label = "qemu-img binary" })
	return bin
end

local function encode_img_opts(v)
	if v == nil then return nil end
	return encode_kv(v, "qemu-img options")
end

function Qemu.img_create(filename, size, opts)
	validate.non_empty_string(filename, "filename")
	if size ~= nil then validate_scalar_or_string(size, "size") end
	opts = opts or {}

	local bin = choose_img_bin(opts)
	local args = { bin, "create" }
	local p = args_util.parser(args, opts)
	p:value_string("format", "-f")
	p:flag("quiet", "-q")
	if opts.options ~= nil then
		args[#args + 1] = "-o"
		args[#args + 1] = encode_img_opts(opts.options)
	end
	p:extra()

	args[#args + 1] = filename
	if size ~= nil then args[#args + 1] = tostring(size) end
	return _cmd.cmd(table.unpack(args))
end

function Qemu.img_info(filename, opts)
	validate.non_empty_string(filename, "filename")
	opts = opts or {}

	local bin = choose_img_bin(opts)
	local args = { bin, "info" }
	local p = args_util.parser(args, opts)
	p:value_string("format", "-f")
	p:bool_or_equals("output", "--output", { validate = validate.non_empty_string })
	p:extra()

	args[#args + 1] = filename
	return _cmd.cmd(table.unpack(args))
end

function Qemu.img_convert(src, dst, opts)
	validate.non_empty_string(dst, "dst")
	opts = opts or {}

	local bin = choose_img_bin(opts)
	local args = { bin, "convert" }
	local p = args_util.parser(args, opts)
	p:value_string("input_format", "-f")
	p:value_string("output_format", "-O")
	p:value_string("backing_file", "-B")
	p:value_string("snapshot", "-s")
	p:flag("compress", "-c")
	p:flag("progress", "-p")
	p:flag("quiet", "-q")
	p:flag("unsafe", "-U")
	p:flag("image_opts", "--image-opts")
	p:flag("target_image_opts", "--target-image-opts")
	if opts.output_options ~= nil then
		args[#args + 1] = "-o"
		args[#args + 1] = encode_img_opts(opts.output_options)
	end
	p:extra()

	local srcs = normalize_string_or_array(src, "src")
	for _, s in ipairs(srcs) do
		validate.non_empty_string(s, "src")
		args[#args + 1] = s
	end
	args[#args + 1] = dst
	return _cmd.cmd(table.unpack(args))
end

function Qemu.img_resize(filename, size, opts)
	validate.non_empty_string(filename, "filename")
	validate_scalar_or_string(size, "size")
	opts = opts or {}

	local bin = choose_img_bin(opts)
	local args = { bin, "resize" }
	local p = args_util.parser(args, opts)
	p:value_string("format", "-f")
	p:bool_or_equals("preallocation", "--preallocation", { validate = validate.non_empty_string })
	p:flag("quiet", "-q")
	p:extra()

	args[#args + 1] = filename
	args[#args + 1] = tostring(size)
	return _cmd.cmd(table.unpack(args))
end

local function img_snapshot(action_flag, filename, name, opts)
	validate.non_empty_string(filename, "filename")
	opts = opts or {}

	local bin = choose_img_bin(opts)
	local args = { bin, "snapshot" }
	local p = args_util.parser(args, opts)
	p:extra()

	if action_flag ~= nil then
		args[#args + 1] = action_flag
		if name ~= nil then
			validate.non_empty_string(name, "snapshot")
			args[#args + 1] = name
		end
	end
	args[#args + 1] = filename
	return _cmd.cmd(table.unpack(args))
end

function Qemu.img_snapshot_list(filename, opts) return img_snapshot("-l", filename, nil, opts) end
function Qemu.img_snapshot_create(filename, name, opts) return img_snapshot("-c", filename, name, opts) end
function Qemu.img_snapshot_apply(filename, name, opts) return img_snapshot("-a", filename, name, opts) end
function Qemu.img_snapshot_delete(filename, name, opts) return img_snapshot("-d", filename, name, opts) end

-- -----------------------------------------------------------------------------
-- qemu-nbd
-- -----------------------------------------------------------------------------

---@class QemuNbdOpts
---@field bin string? Override qemu-nbd binary
---@field object string|string[]? `--object <spec>` (repeatable)
---@field port number? `-p/--port <port>`
---@field offset string|number? `-o/--offset <offset>`
---@field bind string? `-b/--bind <iface>`
---@field socket string? `-k/--socket <path>`
---@field image_opts boolean? `--image-opts`
---@field format string? `-f/--format <fmt>`
---@field read_only boolean? `-r/--read-only`
---@field allocation_depth boolean? `-A/--allocation-depth`
---@field bitmap string? `-B/--bitmap <name>`
---@field snapshot boolean? `-s/--snapshot`
---@field load_snapshot string? `-l/--load-snapshot <param>`
---@field cache string? `--cache <mode>`
---@field nocache boolean? `-n/--nocache`
---@field aio string? `--aio <mode>`
---@field discard string? `--discard <mode>`
---@field detect_zeroes string? `--detect-zeroes <mode>`
---@field shared number? `-e/--shared <num>`
---@field persistent boolean? `-t/--persistent`
---@field export_name string? `-x/--export-name <name>`
---@field description string? `-D/--description <text>`
---@field handshake_limit number? `--handshake-limit <n>`
---@field tls_creds string? `--tls-creds <id>`
---@field tls_hostname string? `--tls-hostname <host>`
---@field tls_authz string? `--tls-authz <id>`
---@field fork boolean? `--fork`
---@field pid_file string? `--pid-file <path>`
---@field verbose boolean? `-v/--verbose`
---@field trace string|string[]? `-T/--trace <spec>` (repeatable)
---@field extra string[]? Extra args

---@class QemuNbdDisconnectOpts
---@field bin string? Override qemu-nbd binary
---@field extra string[]? Extra args

---@class QemuNbdListOpts
---@field bin string? Override qemu-nbd binary
---@field port number? `-p/--port <port>`
---@field bind string? `-b/--bind <iface>`
---@field socket string? `-k/--socket <path>`
---@field tls_creds string? `--tls-creds <id>`
---@field tls_hostname string? `--tls-hostname <host>`
---@field trace string|string[]? `-T/--trace <spec>` (repeatable)
---@field extra string[]? Extra args

local function choose_nbd_bin(opts)
	opts = opts or {}
	local bin = opts.bin or Qemu.nbd_bin
	ensure.bin(bin, { label = "qemu-nbd binary" })
	return bin
end

local function apply_nbd_common(args, opts)
	local p = args_util.parser(args, opts)
	p:repeatable("object", "--object", { validate = validate.non_empty_string })
	p:value_number("port", "-p", { non_negative = true })
	p:value("offset", "-o", { label = "offset", validate = validate_scalar_or_string })
	p:value_string("bind", "-b")
	p:value_string("socket", "-k")
	p:flag("image_opts", "--image-opts")
	p:value_string("format", "-f")
	p:flag("read_only", "-r")
	p:flag("allocation_depth", "-A")
	p:value_string("bitmap", "-B")
	p:flag("snapshot", "-s")
	p:value_string("load_snapshot", "-l")
	p:bool_or_equals("cache", "--cache", { validate = validate.non_empty_string })
	p:flag("nocache", "-n")
	p:bool_or_equals("aio", "--aio", { validate = validate.non_empty_string })
	p:bool_or_equals("discard", "--discard", { validate = validate.non_empty_string })
	p:bool_or_equals("detect_zeroes", "--detect-zeroes", { validate = validate.non_empty_string })
	p:value_number("shared", "-e", { non_negative = true })
	p:flag("persistent", "-t")
	p:value_string("export_name", "-x")
	p:value_string("description", "-D")
	p:value_number("handshake_limit", "--handshake-limit", { non_negative = true, mode = "equals" })
	p:bool_or_equals("tls_creds", "--tls-creds", { validate = validate.non_empty_string })
	p:bool_or_equals("tls_hostname", "--tls-hostname", { validate = validate.non_empty_string })
	p:bool_or_equals("tls_authz", "--tls-authz", { validate = validate.non_empty_string })
	p:flag("fork", "--fork")
	p:bool_or_equals("pid_file", "--pid-file", { validate = validate.non_empty_string })
	p:flag("verbose", "-v")
	p:repeatable("trace", "-T", { validate = validate.non_empty_string })
	p:extra()
end

function Qemu.nbd_serve(filename_or_image_opts, opts)
	validate.non_empty_string(filename_or_image_opts, "filename")
	opts = opts or {}

	local bin = choose_nbd_bin(opts)
	local args = { bin }
	apply_nbd_common(args, opts)
	args[#args + 1] = filename_or_image_opts
	return _cmd.cmd(table.unpack(args))
end

function Qemu.nbd_connect(dev, filename_or_image_opts, opts)
	validate.non_empty_string(dev, "dev")
	validate.non_empty_string(filename_or_image_opts, "filename")
	opts = opts or {}

	local bin = choose_nbd_bin(opts)
	local args = { bin, "-c", dev }
	apply_nbd_common(args, opts)
	args[#args + 1] = filename_or_image_opts
	return _cmd.cmd(table.unpack(args))
end

function Qemu.nbd_disconnect(dev, opts)
	validate.non_empty_string(dev, "dev")
	opts = opts or {}

	local bin = choose_nbd_bin(opts)
	local args = { bin, "-d", dev }
	local p = args_util.parser(args, opts)
	p:extra()
	return _cmd.cmd(table.unpack(args))
end

function Qemu.nbd_list(opts)
	opts = opts or {}

	local bin = choose_nbd_bin(opts)
	local args = { bin, "-L" }
	local p = args_util.parser(args, opts)
	p:value_number("port", "-p", { non_negative = true })
	p:value_string("bind", "-b")
	p:value_string("socket", "-k")
	p:bool_or_equals("tls_creds", "--tls-creds", { validate = validate.non_empty_string })
	p:bool_or_equals("tls_hostname", "--tls-hostname", { validate = validate.non_empty_string })
	p:repeatable("trace", "-T", { validate = validate.non_empty_string })
	p:extra()
	return _cmd.cmd(table.unpack(args))
end

-- -----------------------------------------------------------------------------
-- qemu-storage-daemon
-- -----------------------------------------------------------------------------

---@class QemuStorageDaemonOpts
---@field bin string? Override qemu-storage-daemon binary
---@field chardev (string|table)[]? `--chardev <spec>` (repeatable)
---@field monitor string|string[]? `--monitor <spec>` (repeatable)
---@field object (string|table)[]? `--object <spec>` (repeatable)
---@field blockdev string|string[]? `--blockdev <spec>` (repeatable)
---@field nbd_server string|string[]? `--nbd-server <spec>` (repeatable)
---@field export string|string[]? `--export <spec>` (repeatable)
---@field pidfile string? `--pidfile <path>`
---@field daemonize boolean? `--daemonize`
---@field extra string[]? Extra args

local function choose_storage_daemon_bin(opts)
	opts = opts or {}
	local bin = opts.bin or Qemu.storage_daemon_bin
	ensure.bin(bin, { label = "qemu-storage-daemon binary" })
	return bin
end

function Qemu.storage_daemon(opts)
	opts = opts or {}

	local bin = choose_storage_daemon_bin(opts)
	local args = { bin }

	append_specs(args, "--chardev", normalize_list(opts.chardev, "chardev"), Qemu.chardev)

	local monitors = normalize_string_or_array(opts.monitor or {}, "monitor")
	for _, m in ipairs(monitors) do
		validate.non_empty_string(m, "monitor")
		args[#args + 1] = "--monitor"
		args[#args + 1] = tostring(m)
	end

	append_specs(args, "--object", normalize_list(opts.object, "object"), Qemu.object)

	local blockdevs = normalize_string_or_array(opts.blockdev or {}, "blockdev")
	for _, b in ipairs(blockdevs) do
		args[#args + 1] = "--blockdev"
		args[#args + 1] = encode_kv(b, "blockdev")
	end

	local servers = normalize_string_or_array(opts.nbd_server or {}, "nbd_server")
	for _, s in ipairs(servers) do
		args[#args + 1] = "--nbd-server"
		args[#args + 1] = encode_kv(s, "nbd-server")
	end

	local exports = normalize_string_or_array(opts.export or {}, "export")
	for _, e in ipairs(exports) do
		args[#args + 1] = "--export"
		args[#args + 1] = encode_kv(e, "export")
	end

	local p = args_util.parser(args, opts)
	p:bool_or_equals("pidfile", "--pidfile", { validate = validate.non_empty_string })
	p:flag("daemonize", "--daemonize")
	p:extra()

	return _cmd.cmd(table.unpack(args))
end

return {
	Qemu = Qemu,
}
