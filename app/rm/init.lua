---@diagnostic disable: undefined-doc-name

-- rm wrapper module
--
-- Thin wrappers around `rm` that construct CLI invocations and return
-- `ward.process.cmd(...)` objects.
--
-- This module intentionally does not parse output.

local _cmd = require("ward.process")
local validate = require("util.validate")
local ensure = require("tools.ensure")
local args_util = require("util.args")

---@class RmOpts
---@field force boolean? `-f`
---@field interactive boolean? `-i`
---@field recursive boolean? `-r, -R`
---@field dir boolean? `-d` (remove empty directories)
---@field verbose boolean? `-v` (GNU)
---@field extra string[]? Extra args appended after modeled options

---@class Rm
---@field bin string Executable name or path to `rm`
---@field remove fun(paths: string|string[], opts: RmOpts|nil): ward.Cmd
---@field raw fun(argv: string|string[], opts: RmOpts|nil): ward.Cmd
local Rm = {
	bin = "rm",
}

---@param args string[]
---@param opts RmOpts|nil
local function apply_opts(args, opts)
	opts = opts or {}
	if opts.force and opts.interactive then
		error("force and interactive are mutually exclusive")
	end
	if opts.force then
		args[#args + 1] = "-f"
	end
	if opts.interactive then
		args[#args + 1] = "-i"
	end
	if opts.recursive then
		args[#args + 1] = "-r"
	end
	if opts.dir then
		args[#args + 1] = "-d"
	end
	if opts.verbose then
		args[#args + 1] = "-v"
	end
	args_util.append_extra(args, opts.extra)
end

---Remove file(s) / dir(s).
---
---Builds: `rm <opts...> -- <paths...>`
---@param paths string|string[]
---@param opts RmOpts|nil
---@return ward.Cmd
function Rm.remove(paths, opts)
	ensure.bin(Rm.bin, { label = "rm binary" })
	local list = args_util.normalize_string_or_array(paths, "paths")
	assert(#list > 0, "paths must not be empty")

	local args = { Rm.bin }
	apply_opts(args, opts)
	args[#args + 1] = "--"
	for _, p in ipairs(list) do
		args[#args + 1] = p
	end
	return _cmd.cmd(table.unpack(args))
end

---Low-level escape hatch.
---Builds: `rm <modeled-opts...> <argv...>`
---@param argv string|string[]
---@param opts RmOpts|nil
---@return ward.Cmd
function Rm.raw(argv, opts)
	ensure.bin(Rm.bin, { label = "rm binary" })
	local args = { Rm.bin }
	apply_opts(args, opts)
	local av = args_util.normalize_string_or_array(argv, "argv")
	for _, s in ipairs(av) do
		args[#args + 1] = s
	end
	return _cmd.cmd(table.unpack(args))
end

return {
	Rm = Rm,
}
