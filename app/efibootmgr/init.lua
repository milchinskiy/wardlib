---@diagnostic disable: undefined-doc-name

-- efibootmgr wrapper module
--
-- Thin wrapper around `efibootmgr` that constructs CLI invocations and returns
-- `ward.process.cmd(...)` objects.
--
-- This module models the most common actions and flags. Everything else can be
-- passed through via `opts.extra`.

local _cmd = require("ward.process")
local _env = require("ward.env")
local _fs = require("ward.fs")

---@class EfibootmgrOpts
---@field bin string? Override binary (name or absolute path)
---@field verbose boolean? Add `-v`
---@field quiet boolean? Add `-q`
---@field bootnum string|number? Add `-b XXXX`
---@field active boolean? Add `-a`
---@field inactive boolean? Add `-A`
---@field delete_bootnum boolean? Add `-B`
---@field create boolean? Add `-c`
---@field create_only boolean? Add `-C`
---@field disk string? Add `-d <disk>`
---@field part number? Add `-p <part>`
---@field loader string? Add `-l <loader>`
---@field label string? Add `-L <label>`
---@field bootnext string|number? Add `-n XXXX`
---@field delete_bootnext boolean? Add `-N`
---@field bootorder (string|number)[]|string? Add `-o ...`
---@field delete_bootorder boolean? Add `-O`
---@field timeout number? Add `-t <seconds>`
---@field delete_timeout boolean? Add `-T`
---@field unicode boolean? Add `-u`
---@field write_signature boolean? Add `-w`
---@field remove_dups boolean? Add `-D`
---@field driver boolean? Add `-r`
---@field sysprep boolean? Add `-y`
---@field full_dev_path boolean? Add `--full-dev-path`
---@field file_dev_path boolean? Add `--file-dev-path`
---@field append_binary_args string? Add `-@ <file>` (use "-" to read from stdin)
---@field extra string[]? Extra args appended at the end

---@class Efibootmgr
---@field bin string Default executable name
---@field cmd fun(opts: EfibootmgrOpts|nil): ward.Cmd
---@field list fun(opts: EfibootmgrOpts|nil): ward.Cmd
---@field set_bootnext fun(bootnum: string|number, opts: EfibootmgrOpts|nil): ward.Cmd
---@field delete_bootnext fun(opts: EfibootmgrOpts|nil): ward.Cmd
---@field set_bootorder fun(order: (string|number)[]|string, opts: EfibootmgrOpts|nil): ward.Cmd
---@field delete_bootorder fun(opts: EfibootmgrOpts|nil): ward.Cmd
---@field set_timeout fun(seconds: number, opts: EfibootmgrOpts|nil): ward.Cmd
---@field delete_timeout fun(opts: EfibootmgrOpts|nil): ward.Cmd
---@field delete fun(bootnum: string|number, opts: EfibootmgrOpts|nil): ward.Cmd
---@field create_entry fun(opts: EfibootmgrOpts): ward.Cmd
local Efibootmgr = {
	bin = "efibootmgr",
}

local function validate_bin(bin, label)
	assert(type(bin) == "string" and #bin > 0, label .. " binary is not set")
	if bin:find("/", 1, true) then
		assert(_fs.is_exists(bin), string.format("%s binary does not exist: %s", label, bin))
		assert(_fs.is_executable(bin), string.format("%s binary is not executable: %s", label, bin))
	else
		assert(_env.is_in_path(bin), string.format("%s binary is not in PATH: %s", label, bin))
	end
end

local function validate_token(value, label)
	assert(type(value) == "string" and #value > 0, label .. " must be a non-empty string")
	assert(value:sub(1, 1) ~= "-", label .. " must not start with '-': " .. tostring(value))
	assert(not value:find("%s"), label .. " must not contain whitespace: " .. tostring(value))
end

local function append_extra(args, extra)
	if extra == nil then
		return
	end
	assert(type(extra) == "table", "extra must be an array")
	for _, v in ipairs(extra) do
		table.insert(args, tostring(v))
	end
end

local function to_hex4(v, label)
	if type(v) == "number" then
		assert(v >= 0 and v <= 0xFFFF and math.floor(v) == v, label .. " must be an integer in [0, 65535]")
		return string.format("%04X", v)
	end
	assert(type(v) == "string" and #v > 0, label .. " must be a non-empty string or number")
	assert(not v:find("%s"), label .. " must not contain whitespace")
	assert(v:sub(1, 1) ~= "-", label .. " must not start with '-'")
	assert(v:match("^[0-9a-fA-F]+$"), label .. " must be hex")
	assert(#v <= 4, label .. " must be up to 4 hex digits")
	return string.format("%04s", v):upper()
end

local function join_bootorder(value)
	if type(value) == "string" then
		assert(#value > 0, "bootorder must be non-empty")
		assert(not value:find("%s"), "bootorder string must not contain whitespace")
		return value
	end
	assert(type(value) == "table", "bootorder must be a string or array")
	local out = {}
	for _, v in ipairs(value) do
		out[#out + 1] = to_hex4(v, "bootorder entry")
	end
	return table.concat(out, ",")
end

function Efibootmgr.cmd(opts)
	opts = opts or {}
	local bin = opts.bin or Efibootmgr.bin
	validate_bin(bin, "efibootmgr")

	local args = { bin }

	if opts.verbose then
		table.insert(args, "-v")
	end
	if opts.quiet then
		table.insert(args, "-q")
	end
	if opts.remove_dups then
		table.insert(args, "-D")
	end
	if opts.write_signature then
		table.insert(args, "-w")
	end
	if opts.driver then
		table.insert(args, "-r")
	end
	if opts.sysprep then
		table.insert(args, "-y")
	end
	if opts.full_dev_path then
		table.insert(args, "--full-dev-path")
	end
	if opts.file_dev_path then
		table.insert(args, "--file-dev-path")
	end
	if opts.unicode then
		table.insert(args, "-u")
	end

	if opts.bootnum ~= nil then
		table.insert(args, "-b")
		table.insert(args, to_hex4(opts.bootnum, "bootnum"))
	end

	if opts.active then
		table.insert(args, "-a")
	end
	if opts.inactive then
		table.insert(args, "-A")
	end
	if opts.delete_bootnum then
		table.insert(args, "-B")
	end
	if opts.create then
		table.insert(args, "-c")
	end
	if opts.create_only then
		table.insert(args, "-C")
	end

	if opts.disk ~= nil then
		validate_token(opts.disk, "disk")
		table.insert(args, "-d")
		table.insert(args, opts.disk)
	end
	if opts.part ~= nil then
		assert(
			type(opts.part) == "number" and opts.part > 0 and math.floor(opts.part) == opts.part,
			"part must be a positive integer"
		)
		table.insert(args, "-p")
		table.insert(args, tostring(opts.part))
	end
	if opts.loader ~= nil then
		assert(type(opts.loader) == "string" and #opts.loader > 0, "loader must be a non-empty string")
		table.insert(args, "-l")
		table.insert(args, opts.loader)
	end
	if opts.label ~= nil then
		assert(type(opts.label) == "string" and #opts.label > 0, "label must be a non-empty string")
		table.insert(args, "-L")
		table.insert(args, opts.label)
	end

	if opts.bootnext ~= nil then
		table.insert(args, "-n")
		table.insert(args, to_hex4(opts.bootnext, "bootnext"))
	end
	if opts.delete_bootnext then
		table.insert(args, "-N")
	end

	if opts.bootorder ~= nil then
		table.insert(args, "-o")
		table.insert(args, join_bootorder(opts.bootorder))
	end
	if opts.delete_bootorder then
		table.insert(args, "-O")
	end

	if opts.timeout ~= nil then
		assert(
			type(opts.timeout) == "number" and opts.timeout >= 0 and math.floor(opts.timeout) == opts.timeout,
			"timeout must be a non-negative integer"
		)
		table.insert(args, "-t")
		table.insert(args, tostring(opts.timeout))
	end
	if opts.delete_timeout then
		table.insert(args, "-T")
	end

	if opts.append_binary_args ~= nil then
		assert(
			type(opts.append_binary_args) == "string" and #opts.append_binary_args > 0,
			"append_binary_args must be a non-empty string"
		)
		table.insert(args, "-@")
		table.insert(args, opts.append_binary_args)
	end

	append_extra(args, opts.extra)
	return _cmd.cmd(table.unpack(args))
end

function Efibootmgr.list(opts)
	return Efibootmgr.cmd(opts)
end

function Efibootmgr.set_bootnext(bootnum, opts)
	opts = opts or {}
	opts.bootnext = bootnum
	return Efibootmgr.cmd(opts)
end

function Efibootmgr.delete_bootnext(opts)
	opts = opts or {}
	opts.delete_bootnext = true
	return Efibootmgr.cmd(opts)
end

function Efibootmgr.set_bootorder(order, opts)
	opts = opts or {}
	opts.bootorder = order
	return Efibootmgr.cmd(opts)
end

function Efibootmgr.delete_bootorder(opts)
	opts = opts or {}
	opts.delete_bootorder = true
	return Efibootmgr.cmd(opts)
end

function Efibootmgr.set_timeout(seconds, opts)
	opts = opts or {}
	opts.timeout = seconds
	return Efibootmgr.cmd(opts)
end

function Efibootmgr.delete_timeout(opts)
	opts = opts or {}
	opts.delete_timeout = true
	return Efibootmgr.cmd(opts)
end

function Efibootmgr.delete(bootnum, opts)
	opts = opts or {}
	opts.bootnum = bootnum
	opts.delete_bootnum = true
	return Efibootmgr.cmd(opts)
end

---Convenience helper for creating an entry.
---
---This sets `opts.create = true` and builds:
---  efibootmgr -c -d <disk> -p <part> -l <loader> -L <label> ...
---@param opts EfibootmgrOpts
---@return ward.Cmd
function Efibootmgr.create_entry(opts)
	assert(type(opts) == "table", "opts must be a table")
	opts.create = true
	return Efibootmgr.cmd(opts)
end

return {
	Efibootmgr = Efibootmgr,
}
