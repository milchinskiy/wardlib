---@diagnostic disable: undefined-doc-name

-- chmod wrapper module
--
-- Thin wrappers around `chmod` that construct CLI invocations and return
-- `ward.process.cmd(...)` objects.
--
-- This module intentionally does not parse output.

local _cmd = require("ward.process")
local validate = require("util.validate")
local args_util = require("util.args")

---@class ChmodOpts
---@field recursive boolean? `-R`
---@field verbose boolean? `-v`
---@field changes boolean? `-c`
---@field silent boolean? `-f`
---@field reference string? `--reference=<file>` (GNU)
---@field preserve_root boolean? `--preserve-root` (GNU; meaningful with `recursive`)
---@field no_preserve_root boolean? `--no-preserve-root` (GNU)
---@field extra string[]? Extra args appended after modeled options

---@class Chmod
---@field bin string Executable name or path to `chmod`
---@field set fun(paths: string|string[], mode: string, opts: ChmodOpts|nil): ward.Cmd
---@field reference fun(paths: string|string[], ref: string, opts: ChmodOpts|nil): ward.Cmd
---@field raw fun(argv: string|string[], opts: ChmodOpts|nil): ward.Cmd
local Chmod = {
	bin = "chmod",
}

---@param args string[]
---@param opts ChmodOpts|nil
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
	if opts.preserve_root then
		args[#args + 1] = "--preserve-root"
	end
	if opts.no_preserve_root then
		args[#args + 1] = "--no-preserve-root"
	end
	if opts.reference ~= nil then
		validate.non_empty_string(opts.reference, "reference")
		args[#args + 1] = "--reference=" .. tostring(opts.reference)
	end

	args_util.append_extra(args, opts.extra)
end

---@param paths string|string[]
---@return string[]
local function normalize_paths(paths)
	local list = args_util.normalize_string_or_array(paths, "paths")
	assert(#list > 0, "paths must not be empty")
	return list
end

---Set mode for file(s) / dir(s).
---
---Builds: `chmod <opts...> -- <mode> <paths...>`
---@param paths string|string[]
---@param mode string
---@param opts ChmodOpts|nil
---@return ward.Cmd
function Chmod.set(paths, mode, opts)
	validate.bin(Chmod.bin, "chmod binary")
	validate.non_empty_string(mode, "mode")

	local args = { Chmod.bin }
	apply_opts(args, opts)
	args[#args + 1] = "--"
	args[#args + 1] = mode
	for _, p in ipairs(normalize_paths(paths)) do
		args[#args + 1] = p
	end
	return _cmd.cmd(table.unpack(args))
end

---Copy mode from a reference file (GNU).
---
---Builds: `chmod <opts...> --reference=<ref> -- <paths...>`
---@param paths string|string[]
---@param ref string
---@param opts ChmodOpts|nil
---@return ward.Cmd
function Chmod.reference(paths, ref, opts)
	validate.bin(Chmod.bin, "chmod binary")
	validate.non_empty_string(ref, "ref")
	local o = opts or {}
	o.reference = ref

	local args = { Chmod.bin }
	apply_opts(args, o)
	args[#args + 1] = "--"
	for _, p in ipairs(normalize_paths(paths)) do
		args[#args + 1] = p
	end
	return _cmd.cmd(table.unpack(args))
end

---Low-level escape hatch.
---Builds: `chmod <modeled-opts...> <argv...>`
---@param argv string|string[]
---@param opts ChmodOpts|nil
---@return ward.Cmd
function Chmod.raw(argv, opts)
	validate.bin(Chmod.bin, "chmod binary")
	local args = { Chmod.bin }
	apply_opts(args, opts)
	local av = args_util.normalize_string_or_array(argv, "argv")
	for _, s in ipairs(av) do
		args[#args + 1] = s
	end
	return _cmd.cmd(table.unpack(args))
end

return {
	Chmod = Chmod,
}
