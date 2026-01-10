---@diagnostic disable: undefined-doc-name

-- swap wrapper module
--
-- Thin wrappers around:
--   * mkswap
--   * swapon
--   * swapoff
--
-- Wrappers construct `ward.process.cmd(...)` invocations; they do not parse output.

local _cmd = require("ward.process")
local tbl = require("util.table")
local validate = require("util.validate")
local args_util = require("util.args")

---@class MkswapOpts
---@field label string? `-L <label>`
---@field uuid string? `-U <uuid>`
---@field pagesize number? `--pagesize <size>`
---@field force boolean? `-f` / `--force`
---@field check boolean? `-c` check bad blocks
---@field extra string[]? Extra args appended after modeled options

---@class SwaponOpts
---@field all boolean? `-a`
---@field discard string? `--discard[=<policy>]` ("once", "pages" or empty string to pass bare flag)
---@field fixpgsz boolean? `--fixpgsz`
---@field priority number? `-p <prio>`
---@field show boolean? `--show`
---@field noheadings boolean? `--noheadings`
---@field raw boolean? `--raw`
---@field bytes boolean? `--bytes`
---@field output string|string[]? `--output <cols>` (string or array joined by ',')
---@field extra string[]? Extra args appended after modeled options

---@class SwapoffOpts
---@field all boolean? `-a`
---@field verbose boolean? `-v`
---@field extra string[]? Extra args appended after modeled options

---@class Swap
---@field mkswap_bin string
---@field swapon_bin string
---@field swapoff_bin string
---@field mkswap fun(target: string, opts: MkswapOpts|nil): ward.Cmd
---@field swapon fun(targets: string|string[]|nil, opts: SwaponOpts|nil): ward.Cmd
---@field swapoff fun(targets: string|string[]|nil, opts: SwapoffOpts|nil): ward.Cmd
---@field status fun(opts: SwaponOpts|nil): ward.Cmd Convenience: `swapon --show`
---@field disable_all fun(opts: SwapoffOpts|nil): ward.Cmd Convenience: `swapoff -a`
local Swap = {
	mkswap_bin = "mkswap",
	swapon_bin = "swapon",
	swapoff_bin = "swapoff",
}

---@param v any
---@param label string
local function validate_number(v, label)
	assert(type(v) == "number", label .. " must be a number")
end

---@param cols string|string[]
---@return string
local function normalize_cols(cols)
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
---@param opts MkswapOpts|nil
local function apply_mkswap_opts(args, opts)
	opts = opts or {}
	if opts.force then
		table.insert(args, "-f")
	end
	if opts.check then
		table.insert(args, "-c")
	end
	if opts.label ~= nil then
		validate.not_flag(opts.label, "label")
		table.insert(args, "-L")
		table.insert(args, opts.label)
	end
	if opts.uuid ~= nil then
		validate.not_flag(opts.uuid, "uuid")
		table.insert(args, "-U")
		table.insert(args, opts.uuid)
	end
	if opts.pagesize ~= nil then
		validate_number(opts.pagesize, "pagesize")
		assert(opts.pagesize > 0, "pagesize must be > 0")
		table.insert(args, "--pagesize")
		table.insert(args, tostring(opts.pagesize))
	end
	args_util.append_extra(args, opts.extra)
end

---@param args string[]
---@param opts SwaponOpts|nil
local function apply_swapon_opts(args, opts)
	opts = opts or {}
	if opts.all then
		table.insert(args, "-a")
	end
	if opts.fixpgsz then
		table.insert(args, "--fixpgsz")
	end
	if opts.show then
		table.insert(args, "--show")
	end
	if opts.noheadings then
		table.insert(args, "--noheadings")
	end
	if opts.raw then
		table.insert(args, "--raw")
	end
	if opts.bytes then
		table.insert(args, "--bytes")
	end
	if opts.priority ~= nil then
		validate_number(opts.priority, "priority")
		table.insert(args, "-p")
		table.insert(args, tostring(opts.priority))
	end
	if opts.discard ~= nil then
		-- allow empty string meaning bare flag "--discard"
		assert(type(opts.discard) == "string", "discard must be a string")
		if opts.discard == "" then
			table.insert(args, "--discard")
		else
			validate.not_flag(opts.discard, "discard")
			table.insert(args, "--discard=" .. opts.discard)
		end
	end
	if opts.output ~= nil then
		table.insert(args, "--output")
		table.insert(args, normalize_cols(opts.output))
	end
	args_util.append_extra(args, opts.extra)
end

---@param args string[]
---@param opts SwapoffOpts|nil
local function apply_swapoff_opts(args, opts)
	opts = opts or {}
	if opts.all then
		table.insert(args, "-a")
	end
	if opts.verbose then
		table.insert(args, "-v")
	end
	args_util.append_extra(args, opts.extra)
end

---Construct a mkswap command.
---@param target string Path to swap device or file
---@param opts MkswapOpts|nil
---@return ward.Cmd
function Swap.mkswap(target, opts)
	validate.bin(Swap.mkswap_bin, "mkswap binary")
	validate.non_empty_string(target, "target")

	local args = { Swap.mkswap_bin }
	apply_mkswap_opts(args, opts)
	table.insert(args, target)
	return _cmd.cmd(table.unpack(args))
end

---Construct a swapon command.
---
---If `targets` is nil, swapon will run with only modeled options (useful for `--show`).
---@param targets string|string[]|nil
---@param opts SwaponOpts|nil
---@return ward.Cmd
function Swap.swapon(targets, opts)
	validate.bin(Swap.swapon_bin, "swapon binary")

	local args = { Swap.swapon_bin }
	apply_swapon_opts(args, opts)

	if targets ~= nil then
		if type(targets) == "string" then
			validate.non_empty_string(targets, "target")
			table.insert(args, targets)
		elseif type(targets) == "table" then
			assert(#targets > 0, "targets list must be non-empty")
			for _, t in ipairs(targets) do
				validate.non_empty_string(t, "target")
				table.insert(args, t)
			end
		else
			error("targets must be string, string[], or nil")
		end
	end

	return _cmd.cmd(table.unpack(args))
end

---Construct a swapoff command.
---
---If `targets` is nil, swapoff will run with only modeled options (useful for `-a`).
---@param targets string|string[]|nil
---@param opts SwapoffOpts|nil
---@return ward.Cmd
function Swap.swapoff(targets, opts)
	validate.bin(Swap.swapoff_bin, "swapoff binary")

	local args = { Swap.swapoff_bin }
	apply_swapoff_opts(args, opts)

	if targets ~= nil then
		if type(targets) == "string" then
			validate.non_empty_string(targets, "target")
			table.insert(args, targets)
		elseif type(targets) == "table" then
			assert(#targets > 0, "targets list must be non-empty")
			for _, t in ipairs(targets) do
				validate.non_empty_string(t, "target")
				table.insert(args, t)
			end
		else
			error("targets must be string, string[], or nil")
		end
	end

	return _cmd.cmd(table.unpack(args))
end

---Convenience: `swapon --show` (optionally add formatting flags).
---@param opts SwaponOpts|nil
---@return ward.Cmd
function Swap.status(opts)
	local o = tbl.shallow_copy(opts)
	o.show = true
	return Swap.swapon(nil, o)
end

---Convenience: `swapoff -a`.
---@param opts SwapoffOpts|nil
---@return ward.Cmd
function Swap.disable_all(opts)
	local o = tbl.shallow_copy(opts)
	o.all = true
	return Swap.swapoff(nil, o)
end

return {
	Swap = Swap,
}
