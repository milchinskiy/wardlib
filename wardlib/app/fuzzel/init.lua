---@diagnostic disable: undefined-doc-name

-- fuzzel wrapper module
--
-- Thin wrappers around `fuzzel(1)` that construct CLI invocations and return
-- `ward.process.cmd(...)` objects.
--
-- This module intentionally does not parse output.

local _cmd = require("ward.process")
local args_util = require("wardlib.util.args")
local ensure = require("wardlib.tools.ensure")

---@class FuzzelOpts
---@field config string? `--config <file>`
---@field output string? `-o <output>`
---@field font string? `-f <font>`
---@field prompt string? `-p <prompt>`
---@field prompt_only string? `--prompt-only <prompt>`
---@field hide_prompt boolean? `--hide-prompt`
---@field placeholder string? `--placeholder <text>`
---@field search string? `--search <text>`
---@field no_icons boolean? `-I`
---@field anchor string? `-a <anchor>`
---@field lines number? `-l <n>`
---@field width number? `-w <n>`
---@field no_sort boolean? `--no-sort`
---@field extra string[]? Extra argv appended after modeled options

---@class Fuzzel
---@field bin string Executable name or path to `fuzzel`
---@field launcher fun(opts?: FuzzelOpts): ward.Cmd
---@field dmenu fun(opts?: FuzzelOpts): ward.Cmd
local Fuzzel = {
	bin = "fuzzel",
}

---@param args string[]
---@param opts FuzzelOpts|nil
local function apply_opts(args, opts)
	opts = opts or {}
	args_util
		.parser(args, opts)
		:value_string("config", "--config", "config")
		:value_string("output", "-o", "output")
		:value_string("font", "-f", "font")
		:value_string("prompt", "-p", "prompt")
		:value_string("prompt_only", "--prompt-only", "prompt_only")
		:value_string("placeholder", "--placeholder", "placeholder")
		:value_string("search", "--search", "search")
		:value_string("anchor", "-a", "anchor")
		:value_number("lines", "-l", { label = "lines", integer = true, min = 0 })
		:value_number("width", "-w", { label = "width", integer = true, min = 0 })
		:flag("hide_prompt", "--hide-prompt")
		:flag("no_icons", "-I")
		:flag("no_sort", "--no-sort")
		:extra("extra")
end

---Builds: `fuzzel <opts...>`
---@param opts FuzzelOpts|nil
---@return ward.Cmd
function Fuzzel.launcher(opts)
	ensure.bin(Fuzzel.bin, { label = "fuzzel binary" })
	local o = args_util.clone_opts(opts, { "extra" })
	local args = { Fuzzel.bin }
	apply_opts(args, o)
	return _cmd.cmd(table.unpack(args))
end

---Builds: `fuzzel --dmenu <opts...>`
---@param opts FuzzelOpts|nil
---@return ward.Cmd
function Fuzzel.dmenu(opts)
	ensure.bin(Fuzzel.bin, { label = "fuzzel binary" })
	local o = args_util.clone_opts(opts, { "extra" })
	local args = { Fuzzel.bin, "--dmenu" }
	apply_opts(args, o)
	return _cmd.cmd(table.unpack(args))
end

return { Fuzzel = Fuzzel }