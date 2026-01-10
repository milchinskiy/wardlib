---@diagnostic disable: undefined-doc-name

-- Disk partitioning wrapper module
--
-- Thin wrappers around util-linux tools:
--   * cfdisk: curses-based, interactive editor
--
-- These helpers construct CLI invocations and return `ward.process.cmd(...)`
-- objects.

local _proc = require("ward.process")
local validate = require("util.validate")
local args_util = require("util.args")

---@class CfdiskOpts
---@field color "auto"|"never"|"always"|nil Add `--color[=when]`
---@field sector_size integer? Add `--sector-size <n>`
---@field zero boolean? Add `--zero`
---@field read_only boolean? Add `--read-only`
---@field extra string[]? Extra args appended before the device

---@class Cfdisk
---@field bin string Executable name or path to `cfdisk`
---@field edit fun(device: string, opts: CfdiskOpts|nil): ward.Cmd
local Cfdisk = {
	bin = "cfdisk",
}

---Validate a block device argument.
---@param device string
local function validate_device(device)
	assert(type(device) == "string" and #device > 0, "device must be a non-empty string")
	assert(device:sub(1, 1) ~= "-", "device must not start with '-': " .. tostring(device))
	assert(not device:find("%s"), "device must not contain whitespace: " .. tostring(device))
end

---@param args string[]
---@param extra string[]|nil

local function append_extra(args, extra)
	args_util.append_extra(args, extra)
end

---Interactive editor: `cfdisk [opts...] <device>`
---@param device string
---@param opts CfdiskOpts|nil
---@return ward.Cmd
function Cfdisk.edit(device, opts)
	validate.bin(Cfdisk.bin, "cfdisk binary")
	validate_device(device)
	opts = opts or {}

	local args = { Cfdisk.bin }

	if opts.color ~= nil then
		assert(type(opts.color) == "string" and #opts.color > 0, "color must be a non-empty string")
		table.insert(args, "--color=" .. opts.color)
	end
	if opts.sector_size ~= nil then
		assert(
			type(opts.sector_size) == "number"
				and opts.sector_size > 0
				and math.floor(opts.sector_size) == opts.sector_size,
			"sector_size must be a positive integer"
		)
		table.insert(args, "--sector-size")
		table.insert(args, tostring(opts.sector_size))
	end
	if opts.zero then
		table.insert(args, "--zero")
	end
	if opts.read_only then
		table.insert(args, "--read-only")
	end

	append_extra(args, opts.extra)
	table.insert(args, device)
	return _proc.cmd(table.unpack(args))
end

return {
	Cfdisk = Cfdisk,
}
