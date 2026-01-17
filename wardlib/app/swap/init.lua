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
local args_util = require("wardlib.util.args")
local ensure = require("wardlib.tools.ensure")
local tbl = require("wardlib.util.table")
local validate = require("wardlib.util.validate")

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
local function validate_number(v, label) assert(type(v) == "number", label .. " must be a number") end

---@param args string[]
---@param opts MkswapOpts|nil
local function apply_mkswap_opts(args, opts)
	opts = opts or {}
	args_util
		.parser(args, opts)
		:flag("force", "-f")
		:flag("check", "-c")
		:value_token("label", "-L", "label")
		:value_token("uuid", "-U", "uuid")
		:value_number("pagesize", "--pagesize", { label = "pagesize", min = 0 })
		:extra("extra")

	if opts.pagesize ~= nil then assert(opts.pagesize > 0, "pagesize must be > 0") end
end

---@param args string[]
---@param opts SwaponOpts|nil
local function apply_swapon_opts(args, opts)
	opts = opts or {}
	local p = args_util.parser(args, opts)
	p:flag("all", "-a")
		:flag("fixpgsz", "--fixpgsz")
		:flag("show", "--show")
		:flag("noheadings", "--noheadings")
		:flag("raw", "--raw")
		:flag("bytes", "--bytes")
		:value_number("priority", "-p", { label = "priority" })

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
		table.insert(args, args_util.join_csv(opts.output, "output"))
	end

	p:extra("extra")
end

---@param args string[]
---@param opts SwapoffOpts|nil
local function apply_swapoff_opts(args, opts)
	opts = opts or {}
	args_util.parser(args, opts):flag("all", "-a"):flag("verbose", "-v"):extra("extra")
end

---Construct a mkswap command.
---@param target string Path to swap device or file
---@param opts MkswapOpts|nil
---@return ward.Cmd
function Swap.mkswap(target, opts)
	ensure.bin(Swap.mkswap_bin, { label = "mkswap binary" })
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
	ensure.bin(Swap.swapon_bin, { label = "swapon binary" })

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
	ensure.bin(Swap.swapoff_bin, { label = "swapoff binary" })

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
