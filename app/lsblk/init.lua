---@diagnostic disable: undefined-doc-name

-- lsblk wrapper module
--
-- Thin wrappers around `lsblk` that construct CLI invocations and return
-- `ward.process.cmd(...)` objects.
--
-- This module intentionally does not parse output; consumers can decide how to
-- execute returned commands and interpret results.

local _cmd = require("ward.process")
local _env = require("ward.env")
local _fs = require("ward.fs")

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

---@param bin string
local function validate_bin(bin)
	assert(type(bin) == "string" and #bin > 0, "lsblk binary is not set")
	if bin:find("/", 1, true) then
		assert(_fs.is_exists(bin), string.format("lsblk binary does not exist: %s", bin))
		assert(_fs.is_executable(bin), string.format("lsblk binary is not executable: %s", bin))
	else
		assert(_env.is_in_path(bin), string.format("lsblk binary is not in PATH: %s", bin))
	end
end

---@param s any
---@param label string
local function validate_non_empty_string(s, label)
	assert(type(s) == "string" and #s > 0, label .. " must be a non-empty string")
end

---@param cols string|string[]
---@return string
local function normalize_output_cols(cols)
	if type(cols) == "string" then
		validate_non_empty_string(cols, "output")
		return cols
	end
	assert(type(cols) == "table", "output must be a string or string[]")
	assert(#cols > 0, "output must be non-empty")
	local parts = {}
	for _, c in ipairs(cols) do
		validate_non_empty_string(c, "output col")
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
		validate_non_empty_string(opts.sort, "sort")
		assert(opts.sort:sub(1, 1) ~= "-", "sort must not start with '-': " .. tostring(opts.sort))
		table.insert(args, "--sort")
		table.insert(args, opts.sort)
	end
	if opts.output ~= nil then
		table.insert(args, "-o")
		table.insert(args, normalize_output_cols(opts.output))
	end
	if opts.extra ~= nil then
		assert(type(opts.extra) == "table", "extra must be an array")
		for _, v in ipairs(opts.extra) do
			table.insert(args, tostring(v))
		end
	end
end

---Construct an lsblk command.
---
---If `devices` is nil, lsblk will enumerate all block devices.
---
---@param devices string|string[]|nil
---@param opts LsblkOpts|nil
---@return ward.Cmd
function Lsblk.list(devices, opts)
	validate_bin(Lsblk.bin)

	local args = { Lsblk.bin }
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

return {
	Lsblk = Lsblk,
}
