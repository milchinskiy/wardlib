---@diagnostic disable: undefined-doc-name

-- blkid wrapper module
--
-- Thin wrappers around `blkid` that construct CLI invocations and return
-- `ward.process.cmd(...)` objects.
--
-- This module intentionally does not parse output; consumers can decide how to
-- execute returned commands and interpret results.

local _cmd = require("ward.process")
local validate = require("util.validate")
local ensure = require("tools.ensure")
local args_util = require("util.args")

---@alias BlkidOutputFmt "full"|"value"|"device"|"export"|"udev"

---@class BlkidOpts
---@field output BlkidOutputFmt? `-o <fmt>` (full, value, device, export, udev)
---@field tags string[]? `-s <tag>` repeated (e.g. {"UUID", "TYPE"})
---@field match string|string[]? `-t <token>` repeated (e.g. "TYPE=ext4")
---@field cache_file string? `-c <file>` (use "/dev/null" to disable cache)
---@field probe boolean? `-p` (low-level probe)
---@field wipe_cache boolean? `-w` / `--wipe-cache`
---@field garbage_collect boolean? `-g` / `--garbage-collect`
---@field extra string[]? Extra args appended after modeled options

---@class Blkid
---@field bin string Executable name or path to `blkid`
---@field id fun(devices: string|string[]|nil, opts: BlkidOpts|nil): ward.Cmd
---@field by_label fun(label: string): ward.Cmd
---@field by_uuid fun(uuid: string): ward.Cmd
local Blkid = {
	bin = "blkid",
}

---@param args string[]
---@param opts BlkidOpts|nil
local function apply_opts(args, opts)
	opts = opts or {}

	args_util
		.parser(args, opts)
		:flag("probe", "-p")
		:flag("wipe_cache", "-w")
		:flag("garbage_collect", "-g")
		:value_string("cache_file", "-c", "cache_file")
		:value_token("output", "-o", "output")
		:repeatable("tags", "-s", {
			label = "tag",
			validate = function(v, label)
				validate.not_flag(v, label)
			end,
		})
		:repeatable("match", "-t", {
			label = "match",
			validate = function(v, label)
				validate.not_flag(v, label)
			end,
		})
		:extra("extra")
end

---Construct a blkid command.
---
---If `devices` is nil, blkid will probe available devices.
---
---@param devices string|string[]|nil
---@param opts BlkidOpts|nil
---@return ward.Cmd
function Blkid.id(devices, opts)
	ensure.bin(Blkid.bin, { label = "blkid binary" })

	local args = { Blkid.bin }
	apply_opts(args, opts)

	if devices ~= nil then
		if type(devices) == "string" then
			validate.non_empty_string(devices, "device")
			table.insert(args, devices)
		elseif type(devices) == "table" then
			assert(#devices > 0, "devices list must be non-empty")
			for _, d in ipairs(devices) do
				validate.non_empty_string(d, "device")
				table.insert(args, d)
			end
		else
			error("devices must be string, string[], or nil")
		end
	end

	return _cmd.cmd(table.unpack(args))
end

---`blkid -L <label>`
---@param label string
---@return ward.Cmd
function Blkid.by_label(label)
	ensure.bin(Blkid.bin, { label = "blkid binary" })
	validate.not_flag(label, "label")
	return _cmd.cmd(Blkid.bin, "-L", label)
end

---`blkid -U <uuid>`
---@param uuid string
---@return ward.Cmd
function Blkid.by_uuid(uuid)
	ensure.bin(Blkid.bin, { label = "blkid binary" })
	validate.not_flag(uuid, "uuid")
	return _cmd.cmd(Blkid.bin, "-U", uuid)
end

return {
	Blkid = Blkid,
}
