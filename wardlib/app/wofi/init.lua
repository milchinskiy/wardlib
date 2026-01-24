---@diagnostic disable: undefined-doc-name

-- wofi wrapper module
--
-- Thin wrappers around `wofi(1)` that construct CLI invocations and return
-- `ward.process.cmd(...)` objects.
--
-- This module intentionally does not parse output.

local _cmd = require("ward.process")
local args_util = require("wardlib.util.args")
local ensure = require("wardlib.tools.ensure")

---@class WofiOpts
---@field conf string? `--conf <file>`
---@field style string? `--style <file>`
---@field prompt string? `--prompt <text>`
---@field term string? `--term <terminal>`
---@field insensitive boolean? `--insensitive`
---@field show_icons boolean? `--allow-images`
---@field allow_markup boolean? `--allow-markup`
---@field gtk_dark boolean? `--gtk-dark`
---@field normal_window boolean? `--normal-window`
---@field cache_file string? `--cache-file <file>`
---@field width string? `--width <width>`
---@field height string? `--height <height>`
---@field lines number? `--lines <n>`
---@field columns number? `--columns <n>`
---@field extra string[]? Extra argv appended after modeled options

---@class Wofi
---@field bin string Executable name or path to `wofi`
---@field dmenu fun(opts?: WofiOpts): ward.Cmd
---@field show fun(mode: string, opts?: WofiOpts): ward.Cmd
local Wofi = {
	bin = "wofi",
}

---@param args string[]
---@param opts WofiOpts|nil
local function apply_opts(args, opts)
	opts = opts or {}
	args_util
		.parser(args, opts)
		:value_string("conf", "--conf", "conf")
		:value_string("style", "--style", "style")
		:value_string("prompt", "--prompt", "prompt")
		:value_string("term", "--term", "term")
		:value_string("cache_file", "--cache-file", "cache_file")
		:value_string("width", "--width", "width")
		:value_string("height", "--height", "height")
		:value_number("lines", "--lines", { label = "lines", integer = true, min = 0 })
		:value_number("columns", "--columns", { label = "columns", integer = true, min = 0 })
		:flag("insensitive", "--insensitive")
		:flag("show_icons", "--allow-images")
		:flag("allow_markup", "--allow-markup")
		:flag("gtk_dark", "--gtk-dark")
		:flag("normal_window", "--normal-window")
		:extra("extra")
end

---Builds: `wofi <opts...> --dmenu`
---@param opts WofiOpts|nil
---@return ward.Cmd
function Wofi.dmenu(opts)
	ensure.bin(Wofi.bin, { label = "wofi binary" })
	local o = args_util.clone_opts(opts, { "extra" })
	local args = { Wofi.bin }
	apply_opts(args, o)
	args[#args + 1] = "--dmenu"
	return _cmd.cmd(table.unpack(args))
end

---Builds: `wofi <opts...> --show <mode>`
---@param mode string
---@param opts WofiOpts|nil
---@return ward.Cmd
function Wofi.show(mode, opts)
	ensure.bin(Wofi.bin, { label = "wofi binary" })
	assert(type(mode) == "string" and #mode > 0, "mode must be a non-empty string")
	local o = args_util.clone_opts(opts, { "extra" })
	local args = { Wofi.bin }
	apply_opts(args, o)
	args[#args + 1] = "--show"
	args[#args + 1] = mode
	return _cmd.cmd(table.unpack(args))
end

return { Wofi = Wofi }