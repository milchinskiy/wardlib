---@diagnostic disable: undefined-doc-name

-- chown wrapper module
--
-- Thin wrappers around `chown` that construct CLI invocations and return
-- `ward.process.cmd(...)` objects.
--
-- This module intentionally does not parse output.

local _cmd = require("ward.process")
local validate = require("util.validate")
local ensure = require("tools.ensure")
local args_util = require("util.args")

---@class ChownOpts
---@field recursive boolean? `-R`
---@field verbose boolean? `-v`
---@field changes boolean? `-c`
---@field silent boolean? `-f`
---@field preserve_root boolean? `--preserve-root` (GNU; meaningful with `recursive`)
---@field no_preserve_root boolean? `--no-preserve-root` (GNU)
---@field dereference boolean? `-h` (affects symlinks)
---@field extra string[]? Extra args appended after modeled options

---@class Chown
---@field bin string Executable name or path to `chown`
---@field set fun(paths: string|string[], owner: string|nil, group: string|nil, opts: ChownOpts|nil): ward.Cmd
---@field raw fun(argv: string|string[], opts: ChownOpts|nil): ward.Cmd
local Chown = {
	bin = "chown",
}

---@param args string[]
---@param opts ChownOpts|nil
local function apply_opts(args, opts)
	opts = opts or {}

	if opts.preserve_root and opts.no_preserve_root then
		error("preserve_root and no_preserve_root are mutually exclusive")
	end

	if opts.recursive then
		args[#args + 1] = "-R"
	end
	if opts.verbose then
		args[#args + 1] = "-v"
	end
	if opts.changes then
		args[#args + 1] = "-c"
	end
	if opts.silent then
		args[#args + 1] = "-f"
	end
	if opts.dereference then
		args[#args + 1] = "-h"
	end
	if opts.preserve_root then
		args[#args + 1] = "--preserve-root"
	end
	if opts.no_preserve_root then
		args[#args + 1] = "--no-preserve-root"
	end

	args_util.append_extra(args, opts.extra)
end

---@param owner string|nil
---@param group string|nil
---@return string
local function build_spec(owner, group)
	if owner == nil and group == nil then
		error("either owner or group must be provided")
	end
	if owner ~= nil then
		validate.non_empty_string(owner, "owner")
	end
	if group ~= nil then
		validate.non_empty_string(group, "group")
	end
	if owner == nil then
		return ":" .. group
	end
	if group == nil then
		return owner
	end
	return owner .. ":" .. group
end

---Set owner and/or group for file(s) / dir(s).
---
---Builds: `chown <opts...> -- <owner[:group]> <paths...>`
---@param paths string|string[]
---@param owner string|nil
---@param group string|nil
---@param opts ChownOpts|nil
---@return ward.Cmd
function Chown.set(paths, owner, group, opts)
	ensure.bin(Chown.bin, { label = "chown binary" })
	local list = args_util.normalize_string_or_array(paths, "paths")
	assert(#list > 0, "paths must not be empty")
	local spec = build_spec(owner, group)

	local args = { Chown.bin }
	apply_opts(args, opts)
	args[#args + 1] = "--"
	args[#args + 1] = spec
	for _, p in ipairs(list) do
		args[#args + 1] = p
	end
	return _cmd.cmd(table.unpack(args))
end

---Low-level escape hatch.
---Builds: `chown <modeled-opts...> <argv...>`
---@param argv string|string[]
---@param opts ChownOpts|nil
---@return ward.Cmd
function Chown.raw(argv, opts)
	ensure.bin(Chown.bin, { label = "chown binary" })
	local args = { Chown.bin }
	apply_opts(args, opts)
	local av = args_util.normalize_string_or_array(argv, "argv")
	for _, s in ipairs(av) do
		args[#args + 1] = s
	end
	return _cmd.cmd(table.unpack(args))
end

return {
	Chown = Chown,
}
