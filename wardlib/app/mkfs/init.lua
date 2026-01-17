---@diagnostic disable: undefined-doc-name

-- mkfs wrapper module
--
-- Thin wrappers around `mkfs` and `mkfs.<fstype>` that construct CLI invocations
-- and return `ward.process.cmd(...)` objects.
--
-- The module prefers `mkfs.<fstype>` when available in PATH.
-- Otherwise it falls back to `mkfs -t <fstype>`.
--
-- Filesystem-specific flags are intentionally not modeled; pass them via
-- `opts.extra`.

local _cmd = require("ward.process")
local _env = require("ward.env")
local args_util = require("wardlib.util.args")
local ensure = require("wardlib.tools.ensure")

---@class MkfsOpts
---@field bin string? Override binary (name or absolute path). When set, it is used directly and no `-t` is added.
---@field extra string[]? Extra args appended before the device.

---@class Mkfs
---@field bin string Default frontend binary, usually "mkfs"
---@field format fun(fstype: string, device: string, opts: MkfsOpts|nil): ward.Cmd
---@field ext4 fun(device: string, opts: MkfsOpts|nil): ward.Cmd
---@field xfs fun(device: string, opts: MkfsOpts|nil): ward.Cmd
---@field btrfs fun(device: string, opts: MkfsOpts|nil): ward.Cmd
---@field vfat fun(device: string, opts: MkfsOpts|nil): ward.Cmd
---@field f2fs fun(device: string, opts: MkfsOpts|nil): ward.Cmd
local Mkfs = {
	bin = "mkfs",
}

local function validate_token(value, label)
	assert(type(value) == "string" and #value > 0, label .. " must be a non-empty string")
	assert(value:sub(1, 1) ~= "-", label .. " must not start with '-': " .. tostring(value))
	assert(not value:find("%s"), label .. " must not contain whitespace: " .. tostring(value))
end

local function append_extra(args, extra) args_util.append_extra(args, extra) end

---@param fstype string
---@param opts MkfsOpts|nil
---@return string chosen_bin
---@return boolean needs_t whether to insert `-t <fstype>`
local function choose_bin(fstype, opts)
	opts = opts or {}
	if opts.bin ~= nil then
		ensure.bin(opts.bin, { label = "mkfs binary" })
		return opts.bin, false
	end

	local specific = "mkfs." .. fstype
	if _env.is_in_path(specific) then return specific, false end

	ensure.bin(Mkfs.bin, { label = "mkfs binary" })
	return Mkfs.bin, true
end

---Format a device.
---
---If `mkfs.<fstype>` exists in PATH, it is used directly.
---Otherwise: `mkfs -t <fstype> ... <device>`.
---@param fstype string
---@param device string
---@param opts MkfsOpts|nil
---@return ward.Cmd
function Mkfs.format(fstype, device, opts)
	validate_token(fstype, "fstype")
	validate_token(device, "device")

	local bin, needs_t = choose_bin(fstype, opts)
	local args = { bin }

	if needs_t then
		table.insert(args, "-t")
		table.insert(args, fstype)
	end

	opts = opts or {}
	append_extra(args, opts.extra)
	table.insert(args, device)
	return _cmd.cmd(table.unpack(args))
end

function Mkfs.ext4(device, opts) return Mkfs.format("ext4", device, opts) end

function Mkfs.xfs(device, opts) return Mkfs.format("xfs", device, opts) end

function Mkfs.btrfs(device, opts) return Mkfs.format("btrfs", device, opts) end

function Mkfs.vfat(device, opts) return Mkfs.format("vfat", device, opts) end

function Mkfs.f2fs(device, opts) return Mkfs.format("f2fs", device, opts) end

return {
	Mkfs = Mkfs,
}
