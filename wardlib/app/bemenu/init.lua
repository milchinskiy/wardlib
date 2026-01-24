---@diagnostic disable: undefined-doc-name

-- bemenu wrapper module
--
-- Thin wrappers around `bemenu` and `bemenu-run` that construct CLI invocations
-- and return `ward.process.cmd(...)` objects.
--
-- This module intentionally does not parse output.

local _cmd = require("ward.process")
local args_util = require("wardlib.util.args")
local ensure = require("wardlib.tools.ensure")

---@class BemenuOpts
---@field prompt string? `-p <text>`
---@field lines number? `-l <n>`
---@field ignorecase boolean? `-i`
---@field center boolean? `-c`
---@field fork boolean? `-f`
---@field no_cursor boolean? `-C`
---@field extra string[]? Extra argv appended after modeled options

---@class Bemenu
---@field bin string Executable name or path to `bemenu`
---@field bin_run string Executable name or path to `bemenu-run`
---@field menu fun(opts?: BemenuOpts): ward.Cmd
---@field run fun(opts?: BemenuOpts): ward.Cmd
local Bemenu = {
	bin = "bemenu",
	bin_run = "bemenu-run",
}

---@param args string[]
---@param opts BemenuOpts|nil
local function apply_opts(args, opts)
	opts = opts or {}
	args_util
		.parser(args, opts)
		:flag("ignorecase", "-i")
		:flag("center", "-c")
		:flag("fork", "-f")
		:flag("no_cursor", "-C")
		:value_number("lines", "-l", { label = "lines", integer = true, min = 0 })
		:value_string("prompt", "-p", "prompt")
		:extra("extra")
end

---@param bin string
---@param opts BemenuOpts|nil
---@return ward.Cmd
local function run_bin(bin, opts)
	ensure.bin(bin, { label = "bemenu binary" })
	local o = args_util.clone_opts(opts, { "extra" })
	local args = { bin }
	apply_opts(args, o)
	return _cmd.cmd(table.unpack(args))
end

---Builds: `bemenu <opts...>`
---@param opts BemenuOpts|nil
---@return ward.Cmd
function Bemenu.menu(opts) return run_bin(Bemenu.bin, opts) end

---Builds: `bemenu-run <opts...>`
---@param opts BemenuOpts|nil
---@return ward.Cmd
function Bemenu.run(opts) return run_bin(Bemenu.bin_run, opts) end

return { Bemenu = Bemenu }