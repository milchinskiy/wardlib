---@diagnostic disable: undefined-doc-name

-- mkdir wrapper module
--
-- Thin wrappers around `mkdir` that construct CLI invocations and return
-- `ward.process.cmd(...)` objects.
--
-- This module intentionally does not parse output.

local _cmd = require("ward.process")
local validate = require("util.validate")
local args_util = require("util.args")

---@class MkdirOpts
---@field parents boolean? `-p`
---@field verbose boolean? `-v`
---@field mode string? `-m <mode>`
---@field dry_run boolean? `--dry-run` (GNU)
---@field extra string[]? Extra args appended after modeled options

---@class Mkdir
---@field bin string Executable name or path to `mkdir`
---@field make fun(paths: string|string[], opts: MkdirOpts|nil): ward.Cmd
---@field raw fun(argv: string|string[], opts: MkdirOpts|nil): ward.Cmd
local Mkdir = {
	bin = "mkdir",
}

---@param args string[]
---@param opts MkdirOpts|nil
local function apply_opts(args, opts)
	opts = opts or {}

	if opts.parents then
		args[#args + 1] = "-p"
	end
	if opts.verbose then
		args[#args + 1] = "-v"
	end
	if opts.mode ~= nil then
		validate.non_empty_string(opts.mode, "mode")
		args[#args + 1] = "-m"
		args[#args + 1] = opts.mode
	end
	if opts.dry_run then
		args[#args + 1] = "--dry-run"
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

---Create directories.
---
---Builds: `mkdir <opts...> -- <paths...>`
---@param paths string|string[]
---@param opts MkdirOpts|nil
---@return ward.Cmd
function Mkdir.make(paths, opts)
	validate.bin(Mkdir.bin, "mkdir binary")
	local args = { Mkdir.bin }
	apply_opts(args, opts)
	args[#args + 1] = "--"
	for _, p in ipairs(normalize_paths(paths)) do
		args[#args + 1] = p
	end
	return _cmd.cmd(table.unpack(args))
end

---Low-level escape hatch.
---Builds: `mkdir <modeled-opts...> <argv...>`
---@param argv string|string[]
---@param opts MkdirOpts|nil
---@return ward.Cmd
function Mkdir.raw(argv, opts)
	validate.bin(Mkdir.bin, "mkdir binary")
	local args = { Mkdir.bin }
	apply_opts(args, opts)
	local av = args_util.normalize_string_or_array(argv, "argv")
	for _, s in ipairs(av) do
		args[#args + 1] = s
	end
	return _cmd.cmd(table.unpack(args))
end

return {
	Mkdir = Mkdir,
}
