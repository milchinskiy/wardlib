---@diagnostic disable: undefined-doc-name

-- blkid wrapper module
--
-- Thin wrappers around `blkid` that construct CLI invocations and return
-- `ward.process.cmd(...)` objects.
--
-- This module intentionally does not parse output; consumers can decide how to
-- execute returned commands and interpret results.

local _cmd = require("ward.process")
local _env = require("ward.env")
local _fs = require("ward.fs")

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

---@param bin string
local function validate_bin(bin)
	assert(type(bin) == "string" and #bin > 0, "blkid binary is not set")
	if bin:find("/", 1, true) then
		assert(_fs.is_exists(bin), string.format("blkid binary does not exist: %s", bin))
		assert(_fs.is_executable(bin), string.format("blkid binary is not executable: %s", bin))
	else
		assert(_env.is_in_path(bin), string.format("blkid binary is not in PATH: %s", bin))
	end
end

---@param s any
---@param label string
local function validate_non_empty_string(s, label)
	assert(type(s) == "string" and #s > 0, label .. " must be a non-empty string")
end

---@param value string
---@param label string
local function validate_not_flag(value, label)
	validate_non_empty_string(value, label)
	assert(value:sub(1, 1) ~= "-", label .. " must not start with '-': " .. tostring(value))
end

---@param args string[]
---@param opts BlkidOpts|nil
local function apply_opts(args, opts)
	opts = opts or {}

	if opts.probe then
		table.insert(args, "-p")
	end
	if opts.wipe_cache then
		table.insert(args, "-w")
	end
	if opts.garbage_collect then
		table.insert(args, "-g")
	end
	if opts.cache_file ~= nil then
		validate_non_empty_string(opts.cache_file, "cache_file")
		table.insert(args, "-c")
		table.insert(args, opts.cache_file)
	end
	if opts.output ~= nil then
		validate_not_flag(opts.output, "output")
		table.insert(args, "-o")
		table.insert(args, opts.output)
	end
	if opts.tags ~= nil then
		assert(type(opts.tags) == "table", "tags must be an array")
		for _, tag in ipairs(opts.tags) do
			validate_not_flag(tag, "tag")
			table.insert(args, "-s")
			table.insert(args, tag)
		end
	end
	if opts.match ~= nil then
		local tokens = {}
		if type(opts.match) == "string" then
			tokens = { opts.match }
		elseif type(opts.match) == "table" then
			assert(#opts.match > 0, "match list must be non-empty")
			for _, v in ipairs(opts.match) do
				table.insert(tokens, tostring(v))
			end
		else
			error("match must be string or string[]")
		end
		for _, tok in ipairs(tokens) do
			validate_not_flag(tok, "match")
			table.insert(args, "-t")
			table.insert(args, tok)
		end
	end
	if opts.extra ~= nil then
		assert(type(opts.extra) == "table", "extra must be an array")
		for _, v in ipairs(opts.extra) do
			table.insert(args, tostring(v))
		end
	end
end

---Construct a blkid command.
---
---If `devices` is nil, blkid will probe available devices.
---
---@param devices string|string[]|nil
---@param opts BlkidOpts|nil
---@return ward.Cmd
function Blkid.id(devices, opts)
	validate_bin(Blkid.bin)

	local args = { Blkid.bin }
	apply_opts(args, opts)

	if devices ~= nil then
		if type(devices) == "string" then
			validate_non_empty_string(devices, "device")
			table.insert(args, devices)
		elseif type(devices) == "table" then
			assert(#devices > 0, "devices list must be non-empty")
			for _, d in ipairs(devices) do
				validate_non_empty_string(d, "device")
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
	validate_bin(Blkid.bin)
	validate_not_flag(label, "label")
	return _cmd.cmd(Blkid.bin, "-L", label)
end

---`blkid -U <uuid>`
---@param uuid string
---@return ward.Cmd
function Blkid.by_uuid(uuid)
	validate_bin(Blkid.bin)
	validate_not_flag(uuid, "uuid")
	return _cmd.cmd(Blkid.bin, "-U", uuid)
end

return {
	Blkid = Blkid,
}
