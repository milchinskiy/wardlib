---@diagnostic disable: undefined-doc-name

-- dmenu wrapper module
--
-- Thin wrapper around `dmenu(1)` that constructs CLI invocations and returns
-- `ward.process.cmd(...)` objects.
--
-- This module intentionally does not parse output.

local _cmd = require("ward.process")
local args_util = require("wardlib.util.args")
local ensure = require("wardlib.tools.ensure")

---@class DmenuOpts
---@field bottom boolean? `-b`
---@field fast boolean? `-f`
---@field insensitive boolean? `-i`
---@field lines number? `-l <n>`
---@field monitor number? `-m <n>`
---@field prompt string? `-p <text>`
---@field font string? `-fn <font>`
---@field normal_bg string? `-nb <color>`
---@field normal_fg string? `-nf <color>`
---@field selected_bg string? `-sb <color>`
---@field selected_fg string? `-sf <color>`
---@field windowid string? `-w <id>`
---@field extra string[]? Extra argv appended after modeled options

---@class Dmenu
---@field bin string Executable name or path to `dmenu`
---@field menu fun(opts?: DmenuOpts): ward.Cmd
local Dmenu = {
	bin = "dmenu",
}

---@param args string[]
---@param opts DmenuOpts|nil
local function apply_opts(args, opts)
	opts = opts or {}
	local p = args_util.parser(args, opts)

	p:flag("bottom", "-b")
		:flag("fast", "-f")
		:flag("insensitive", "-i")
		:value_number("lines", "-l", { label = "lines", integer = true, min = 0 })
		:value_number("monitor", "-m", { label = "monitor", integer = true, min = 0 })
		:value_string("prompt", "-p", "prompt")
		:value_string("font", "-fn", "font")
		:value_string("normal_bg", "-nb", "normal_bg")
		:value_string("normal_fg", "-nf", "normal_fg")
		:value_string("selected_bg", "-sb", "selected_bg")
		:value_string("selected_fg", "-sf", "selected_fg")
		:value_string("windowid", "-w", "windowid")
		:extra("extra")
end

---Builds: `dmenu <opts...>`
---@param opts DmenuOpts|nil
---@return ward.Cmd
function Dmenu.menu(opts)
	ensure.bin(Dmenu.bin, { label = "dmenu binary" })
	local o = args_util.clone_opts(opts, { "extra" })
	local args = { Dmenu.bin }
	apply_opts(args, o)
	return _cmd.cmd(table.unpack(args))
end

return { Dmenu = Dmenu }