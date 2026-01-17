---@diagnostic disable: undefined-doc-name

-- mkdir wrapper module
--
-- Thin wrappers around `mkdir` that construct CLI invocations and return
-- `ward.process.cmd(...)` objects.
--
-- This module intentionally does not parse output.

local _cmd = require("ward.process")
local args_util = require("wardlib.util.args")
local ensure = require("wardlib.tools.ensure")

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
	args_util
		.parser(args, opts)
		:flag("parents", "-p")
		:flag("verbose", "-v")
		:value_string("mode", "-m")
		:flag("dry_run", "--dry-run")
		:extra()
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
	ensure.bin(Mkdir.bin, { label = "mkdir binary" })
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
	ensure.bin(Mkdir.bin, { label = "mkdir binary" })
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
