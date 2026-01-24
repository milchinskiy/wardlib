---@diagnostic disable: undefined-doc-name

-- rofi wrapper module
--
-- Thin wrappers around `rofi(1)` that construct CLI invocations and return
-- `ward.process.cmd(...)` objects.
--
-- This module intentionally does not parse output.

local _cmd = require("ward.process")
local args_util = require("wardlib.util.args")
local ensure = require("wardlib.tools.ensure")

---@class RofiCommonOpts
---@field config string? `-config <file>`
---@field theme string? `-theme <theme>`
---@field theme_str string? `-theme-str <string>`
---@field modi string? `-modi <modes>`
---@field show_icons boolean? `-show-icons`
---@field terminal string? `-terminal <terminal>`
---@field extra string[]? Extra argv appended after modeled options

---@class RofiDmenuOpts: RofiCommonOpts
---@field sep string? `-sep <sep>`
---@field prompt string? `-p <prompt>`
---@field lines number? `-l <n>`
---@field insensitive boolean? `-i`
---@field only_match boolean? `-only-match`
---@field no_custom boolean? `-no-custom`
---@field format string? `-format <fmt>`
---@field select string? `-select <string>`
---@field mesg string? `-mesg <msg>`
---@field password boolean? `-password`
---@field markup_rows boolean? `-markup-rows`
---@field multi_select boolean? `-multi-select`
---@field sync boolean? `-sync`
---@field input string? `-input <file>`
---@field window_title string? `-window-title <title>`
---@field windowid string? `-w <windowid>`

---@class Rofi
---@field bin string Executable name or path to `rofi`
---@field dmenu fun(opts?: RofiDmenuOpts): ward.Cmd
---@field show fun(mode: string, opts?: RofiCommonOpts): ward.Cmd
local Rofi = {
	bin = "rofi",
}

---@param args string[]
---@param opts RofiCommonOpts|nil
local function apply_common(args, opts)
	opts = opts or {}
	args_util
		.parser(args, opts)
		:value_string("config", "-config", "config")
		:value_string("theme", "-theme", "theme")
		:value_string("theme_str", "-theme-str", "theme_str")
		:value_string("modi", "-modi", "modi")
		:value_string("terminal", "-terminal", "terminal")
		:flag("show_icons", "-show-icons")
end

---@param args string[]
---@param opts RofiDmenuOpts|nil
local function apply_dmenu(args, opts)
	opts = opts or {}
	args_util
		.parser(args, opts)
		:value_string("sep", "-sep", "sep")
		:value_string("prompt", "-p", "prompt")
		:value_number("lines", "-l", { label = "lines", integer = true, min = 0 })
		:flag("insensitive", "-i")
		:flag("only_match", "-only-match")
		:flag("no_custom", "-no-custom")
		:flag("password", "-password")
		:flag("markup_rows", "-markup-rows")
		:flag("multi_select", "-multi-select")
		:flag("sync", "-sync")
		:value_string("format", "-format", "format")
		:value_string("select", "-select", "select")
		:value_string("mesg", "-mesg", "mesg")
		:value_string("input", "-input", "input")
		:value_string("window_title", "-window-title", "window_title")
		:value_string("windowid", "-w", "windowid")
		:extra("extra")
end

---Builds: `rofi <common...> -dmenu <dmenu...>`
---@param opts RofiDmenuOpts|nil
---@return ward.Cmd
function Rofi.dmenu(opts)
	ensure.bin(Rofi.bin, { label = "rofi binary" })
	local o = args_util.clone_opts(opts, { "extra" })
	local args = { Rofi.bin }
	apply_common(args, o)
	args[#args + 1] = "-dmenu"
	apply_dmenu(args, o)
	return _cmd.cmd(table.unpack(args))
end

---Builds: `rofi <common...> -show <mode> <extra...>`
---@param mode string
---@param opts RofiCommonOpts|nil
---@return ward.Cmd
function Rofi.show(mode, opts)
	ensure.bin(Rofi.bin, { label = "rofi binary" })
	assert(type(mode) == "string" and #mode > 0, "mode must be a non-empty string")
	local o = args_util.clone_opts(opts, { "extra" })
	local args = { Rofi.bin }
	apply_common(args, o)
	args[#args + 1] = "-show"
	args[#args + 1] = mode
	args_util.append_extra(args, o and o.extra)
	return _cmd.cmd(table.unpack(args))
end

return { Rofi = Rofi }