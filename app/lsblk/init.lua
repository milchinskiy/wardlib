---@diagnostic disable: undefined-doc-name

-- lsblk wrapper module
--
-- Thin wrappers around `lsblk` that construct CLI invocations and return
-- `ward.process.cmd(...)` objects.
--
-- This module intentionally does not parse output; consumers can decide how to
-- execute returned commands and interpret results.

local _cmd = require("ward.process")
local validate = require("util.validate")
local ensure = require("tools.ensure")
local args_util = require("util.args")

---@class LsblkOpts
---@field json boolean? `-J` / `--json`
---@field output string|string[]? `-o <cols>` (string or array joined by ',')
---@field bytes boolean? `-b`
---@field paths boolean? `-p`
---@field fs boolean? `-f`
---@field all boolean? `-a`
---@field nodeps boolean? `-d`
---@field list boolean? `-l`
---@field raw boolean? `-r`
---@field noheadings boolean? `-n`
---@field sort string? `--sort <col>`
---@field tree boolean? `--tree`
---@field extra string[]? Extra args appended after modeled options

---@class Lsblk
---@field bin string Executable name or path to `lsblk`
---@field list fun(devices: string|string[]|nil, opts: LsblkOpts|nil): ward.Cmd
local Lsblk = {
	bin = "lsblk",
}

---@param cols string|string[]
---@return string
local function normalize_output_cols(cols)
	if type(cols) == "string" then
		validate.non_empty_string(cols, "output")
		return cols
	end
	assert(type(cols) == "table", "output must be a string or string[]")
	assert(#cols > 0, "output must be non-empty")
	local parts = {}
	for _, c in ipairs(cols) do
		validate.non_empty_string(c, "output col")
		table.insert(parts, c)
	end
	return table.concat(parts, ",")
end

---@param args string[]
---@param opts LsblkOpts|nil
local function apply_opts(args, opts)
	opts = opts or {}
	if opts.json then
		table.insert(args, "-J")
	end
	if opts.bytes then
		table.insert(args, "-b")
	end
	if opts.paths then
		table.insert(args, "-p")
	end
	if opts.fs then
		table.insert(args, "-f")
	end
	if opts.all then
		table.insert(args, "-a")
	end
	if opts.nodeps then
		table.insert(args, "-d")
	end
	if opts.list then
		table.insert(args, "-l")
	end
	if opts.raw then
		table.insert(args, "-r")
	end
	if opts.noheadings then
		table.insert(args, "-n")
	end
	if opts.tree then
		table.insert(args, "--tree")
	end
	if opts.sort ~= nil then
		validate.non_empty_string(opts.sort, "sort")
		assert(opts.sort:sub(1, 1) ~= "-", "sort must not start with '-': " .. tostring(opts.sort))
		table.insert(args, "--sort")
		table.insert(args, opts.sort)
	end
	if opts.output ~= nil then
		table.insert(args, "-o")
		table.insert(args, normalize_output_cols(opts.output))
	end
	args_util.append_extra(args, opts.extra)
end

---Construct an lsblk command.
---
---If `devices` is nil, lsblk will enumerate all block devices.
---
---@param devices string|string[]|nil
---@param opts LsblkOpts|nil
---@return ward.Cmd
function Lsblk.list(devices, opts)
	ensure.bin(Lsblk.bin, { label = 'lsblk binary' })

	local args = { Lsblk.bin }
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

return {
	Lsblk = Lsblk,
}
