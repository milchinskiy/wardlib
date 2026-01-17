---@diagnostic disable: undefined-doc-name

-- lsblk wrapper module
--
-- Thin wrappers around `lsblk` that construct CLI invocations and return
-- `ward.process.cmd(...)` objects.
--
-- This module intentionally does not parse output; consumers can decide how to
-- execute returned commands and interpret results.

local _cmd = require("ward.process")
local args_util = require("wardlib.util.args")
local ensure = require("wardlib.tools.ensure")
local validate = require("wardlib.util.validate")

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

---@param args string[]
---@param opts LsblkOpts|nil
local function apply_opts(args, opts)
	opts = opts or {}

	local p = args_util.parser(args, opts)
	p:flag("json", "-J")
		:flag("bytes", "-b")
		:flag("paths", "-p")
		:flag("fs", "-f")
		:flag("all", "-a")
		:flag("nodeps", "-d")
		:flag("list", "-l")
		:flag("raw", "-r")
		:flag("noheadings", "-n")
		:flag("tree", "--tree")
		:value_token("sort", "--sort", "sort")

	if opts.output ~= nil then
		args[#args + 1] = "-o"
		args[#args + 1] = args_util.join_csv(opts.output, "output")
	end

	p:extra("extra")
end

---Construct an lsblk command.
---
---If `devices` is nil, lsblk will enumerate all block devices.
---
---@param devices string|string[]|nil
---@param opts LsblkOpts|nil
---@return ward.Cmd
function Lsblk.list(devices, opts)
	ensure.bin(Lsblk.bin, { label = "lsblk binary" })

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
