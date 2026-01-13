---@diagnostic disable: undefined-doc-name

-- cp wrapper module
--
-- Thin wrappers around `cp` that construct CLI invocations and return
-- `ward.process.cmd(...)` objects.
--
-- This module intentionally does not parse output.

local _cmd = require("ward.process")
local validate = require("wardlib.util.validate")
local ensure = require("wardlib.tools.ensure")
local args_util = require("wardlib.util.args")

---@class CpOpts
---@field recursive boolean? `-r, -R`
---@field force boolean? `-f`
---@field interactive boolean? `-i`
---@field update boolean? `-u`
---@field verbose boolean? `-v`
---@field preserve boolean? `-p`
---@field archive boolean? `-a`
---@field parents boolean? `--parents` (GNU)
---@field target_directory string? `-t <dir>` (GNU)
---@field no_target_directory boolean? `-T` (GNU)
---@field extra string[]? Extra args appended after modeled options

---@class Cp
---@field bin string Executable name or path to `cp`
---@field copy fun(src: string|string[], dest: string, opts: CpOpts|nil): ward.Cmd
---@field into fun(src: string|string[], dir: string, opts: CpOpts|nil): ward.Cmd Copy into directory via `-t` when available
---@field raw fun(argv: string|string[], opts: CpOpts|nil): ward.Cmd
local Cp = {
	bin = "cp",
}

---@param args string[]
---@param opts CpOpts|nil
local function apply_opts(args, opts)
	opts = opts or {}

	if opts.force and opts.interactive then
		error("force and interactive are mutually exclusive")
	end

	args_util
		.parser(args, opts)
		:flag("archive", "-a")
		:flag("recursive", "-r")
		:flag("force", "-f")
		:flag("interactive", "-i")
		:flag("update", "-u")
		:flag("verbose", "-v")
		:flag("preserve", "-p")
		:flag("parents", "--parents")
		:flag("no_target_directory", "-T")
		:value_string("target_directory", "-t")
		:extra()
end

---@param src string|string[]
---@return string[]
local function normalize_src(src)
	local list = args_util.normalize_string_or_array(src, "src")
	assert(#list > 0, "src must not be empty")
	return list
end

---Copy file(s) / dir(s).
---
---Builds: `cp <opts...> -- <src...> <dest>`
---@param src string|string[]
---@param dest string
---@param opts CpOpts|nil
---@return ward.Cmd
function Cp.copy(src, dest, opts)
	ensure.bin(Cp.bin, { label = "cp binary" })
	validate.non_empty_string(dest, "dest")

	local args = { Cp.bin }
	apply_opts(args, opts)
	args[#args + 1] = "--"

	for _, s in ipairs(normalize_src(src)) do
		args[#args + 1] = s
	end
	args[#args + 1] = dest
	return _cmd.cmd(table.unpack(args))
end

---Copy into directory.
---
---Builds: `cp <opts...> -t <dir> -- <src...>`
---
---This uses GNU-style `-t`. If your platform does not support `-t`, prefer `Cp.copy(src, dir, ...)`.
---@param src string|string[]
---@param dir string
---@param opts CpOpts|nil
---@return ward.Cmd
function Cp.into(src, dir, opts)
	validate.non_empty_string(dir, "dir")
	local o = args_util.clone_opts(opts)
	o.target_directory = dir

	ensure.bin(Cp.bin, { label = "cp binary" })
	local args = { Cp.bin }
	apply_opts(args, o)
	args[#args + 1] = "--"
	for _, s in ipairs(normalize_src(src)) do
		args[#args + 1] = s
	end
	return _cmd.cmd(table.unpack(args))
end

---Low-level escape hatch.
---Builds: `cp <modeled-opts...> <argv...>`
---@param argv string|string[]
---@param opts CpOpts|nil
---@return ward.Cmd
function Cp.raw(argv, opts)
	ensure.bin(Cp.bin, { label = "cp binary" })
	local args = { Cp.bin }
	apply_opts(args, opts)
	local av = args_util.normalize_string_or_array(argv, "argv")
	for _, s in ipairs(av) do
		args[#args + 1] = s
	end
	return _cmd.cmd(table.unpack(args))
end

return {
	Cp = Cp,
}
