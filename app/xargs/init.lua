---@diagnostic disable: undefined-doc-name

-- xargs wrapper module
--
-- Thin wrappers around `xargs` that construct CLI invocations and return
-- `ward.process.cmd(...)` objects.
--
-- This module intentionally does not parse output.

local _cmd = require("ward.process")
local validate = require("util.validate")
local ensure = require("tools.ensure")
local args_util = require("util.args")

---@class XargsOpts
---@field null_input boolean? `-0`
---@field delimiter string? `-d <delim>` (GNU)
---@field max_args integer? `-n <n>`
---@field max_procs integer? `-P <n>`
---@field max_chars integer? `-s <n>`
---@field no_run_if_empty boolean? `-r` (GNU)
---@field replace_str string? `-I <str>`
---@field verbose boolean? `-t`
---@field show_limits boolean? `--show-limits` (GNU)
---@field extra string[]? Extra args appended after modeled options

---@class Xargs
---@field bin string Executable name or path to `xargs`
---@field run fun(cmd: string|string[]|nil, opts: XargsOpts|nil): ward.Cmd
---@field raw fun(argv: string|string[], opts: XargsOpts|nil): ward.Cmd
local Xargs = {
	bin = "xargs",
}

---@param args string[]
---@param opts XargsOpts|nil
local function apply_opts(args, opts)
	opts = opts or {}
	if opts.null_input and opts.delimiter ~= nil then
		error("null_input and delimiter are mutually exclusive")
	end
	if opts.null_input then
		args[#args + 1] = "-0"
	end
	if opts.delimiter ~= nil then
		validate.non_empty_string(opts.delimiter, "delimiter")
		args[#args + 1] = "-d"
		args[#args + 1] = tostring(opts.delimiter)
	end
	if opts.max_args ~= nil then
		validate.integer_min(opts.max_args, "max_args", 1)
		args[#args + 1] = "-n"
		args[#args + 1] = tostring(opts.max_args)
	end
	if opts.max_procs ~= nil then
		validate.integer_min(opts.max_procs, "max_procs", 1)
		args[#args + 1] = "-P"
		args[#args + 1] = tostring(opts.max_procs)
	end
	if opts.max_chars ~= nil then
		validate.integer_min(opts.max_chars, "max_chars", 1)
		args[#args + 1] = "-s"
		args[#args + 1] = tostring(opts.max_chars)
	end
	if opts.no_run_if_empty then
		args[#args + 1] = "-r"
	end
	if opts.replace_str ~= nil then
		validate.non_empty_string(opts.replace_str, "replace_str")
		args[#args + 1] = "-I"
		args[#args + 1] = tostring(opts.replace_str)
	end
	if opts.verbose then
		args[#args + 1] = "-t"
	end
	if opts.show_limits then
		args[#args + 1] = "--show-limits"
	end
	args_util.append_extra(args, opts.extra)
end

---Build an xargs command.
---
---Builds: `xargs <opts...> [-- <cmd...>]`
---
---If `cmd` is nil, xargs executes `echo` (implementation-dependent).
---@param cmd string|string[]|nil
---@param opts XargsOpts|nil
---@return ward.Cmd
function Xargs.run(cmd, opts)
	ensure.bin(Xargs.bin, { label = "xargs binary" })
	local args = { Xargs.bin }
	apply_opts(args, opts)
	if cmd ~= nil then
		args[#args + 1] = "--"
		local av = args_util.normalize_string_or_array(cmd, "cmd")
		for _, s in ipairs(av) do
			args[#args + 1] = s
		end
	end
	return _cmd.cmd(table.unpack(args))
end

---Low-level escape hatch.
---Builds: `xargs <modeled-opts...> <argv...>`
---@param argv string|string[]
---@param opts XargsOpts|nil
---@return ward.Cmd
function Xargs.raw(argv, opts)
	ensure.bin(Xargs.bin, { label = "xargs binary" })
	local args = { Xargs.bin }
	apply_opts(args, opts)
	local av = args_util.normalize_string_or_array(argv, "argv")
	for _, s in ipairs(av) do
		args[#args + 1] = s
	end
	return _cmd.cmd(table.unpack(args))
end

return {
	Xargs = Xargs,
}
