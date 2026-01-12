---@diagnostic disable: undefined-doc-name

-- mv wrapper module
--
-- Thin wrappers around `mv` that construct CLI invocations and return
-- `ward.process.cmd(...)` objects.
--
-- This module intentionally does not parse output.

local _cmd = require("ward.process")
local validate = require("util.validate")
local ensure = require("tools.ensure")
local args_util = require("util.args")

---@class MvOpts
---@field force boolean? `-f`
---@field interactive boolean? `-i`
---@field update boolean? `-u`
---@field verbose boolean? `-v`
---@field no_clobber boolean? `-n` (GNU)
---@field backup boolean? `--backup` (GNU)
---@field suffix string? `--suffix=<s>` (GNU)
---@field target_directory string? `-t <dir>` (GNU)
---@field no_target_directory boolean? `-T` (GNU)
---@field extra string[]? Extra args appended after modeled options

---@class Mv
---@field bin string Executable name or path to `mv`
---@field move fun(src: string|string[], dest: string, opts: MvOpts|nil): ward.Cmd
---@field into fun(src: string|string[], dir: string, opts: MvOpts|nil): ward.Cmd Move into directory via `-t` when available
---@field raw fun(argv: string|string[], opts: MvOpts|nil): ward.Cmd
local Mv = {
	bin = "mv",
}

---@param args string[]
---@param opts MvOpts|nil
local function apply_opts(args, opts)
	opts = opts or {}

	if opts.force and opts.interactive then
		error("force and interactive are mutually exclusive")
	end
	if opts.no_clobber and (opts.force or opts.interactive) then
		error("no_clobber is mutually exclusive with force/interactive")
	end

	if opts.force then
		args[#args + 1] = "-f"
	end
	if opts.interactive then
		args[#args + 1] = "-i"
	end
	if opts.update then
		args[#args + 1] = "-u"
	end
	if opts.verbose then
		args[#args + 1] = "-v"
	end
	if opts.no_clobber then
		args[#args + 1] = "-n"
	end
	if opts.backup then
		args[#args + 1] = "--backup"
	end
	if opts.suffix ~= nil then
		validate.non_empty_string(opts.suffix, "suffix")
		args[#args + 1] = "--suffix=" .. tostring(opts.suffix)
	end
	if opts.no_target_directory then
		args[#args + 1] = "-T"
	end
	if opts.target_directory ~= nil then
		validate.non_empty_string(opts.target_directory, "target_directory")
		args[#args + 1] = "-t"
		args[#args + 1] = opts.target_directory
	end

	args_util.append_extra(args, opts.extra)
end

---@param src string|string[]
---@return string[]
local function normalize_src(src)
	local list = args_util.normalize_string_or_array(src, "src")
	assert(#list > 0, "src must not be empty")
	return list
end

---Move file(s) / dir(s).
---
---Builds: `mv <opts...> -- <src...> <dest>`
---@param src string|string[]
---@param dest string
---@param opts MvOpts|nil
---@return ward.Cmd
function Mv.move(src, dest, opts)
	ensure.bin(Mv.bin, { label = "mv binary" })
	validate.non_empty_string(dest, "dest")

	local args = { Mv.bin }
	apply_opts(args, opts)
	args[#args + 1] = "--"
	for _, s in ipairs(normalize_src(src)) do
		args[#args + 1] = s
	end
	args[#args + 1] = dest
	return _cmd.cmd(table.unpack(args))
end

---Move into directory.
---
---Builds: `mv <opts...> -t <dir> -- <src...>`
---
---This uses GNU-style `-t`. If your platform does not support `-t`, prefer `Mv.move(src, dir, ...)`.
---@param src string|string[]
---@param dir string
---@param opts MvOpts|nil
---@return ward.Cmd
function Mv.into(src, dir, opts)
	validate.non_empty_string(dir, "dir")
	local o = args_util.clone_opts(opts)
	o.target_directory = dir

	ensure.bin(Mv.bin, { label = "mv binary" })
	local args = { Mv.bin }
	apply_opts(args, o)
	args[#args + 1] = "--"
	for _, s in ipairs(normalize_src(src)) do
		args[#args + 1] = s
	end
	return _cmd.cmd(table.unpack(args))
end

---Low-level escape hatch.
---Builds: `mv <modeled-opts...> <argv...>`
---@param argv string|string[]
---@param opts MvOpts|nil
---@return ward.Cmd
function Mv.raw(argv, opts)
	ensure.bin(Mv.bin, { label = "mv binary" })
	local args = { Mv.bin }
	apply_opts(args, opts)
	local av = args_util.normalize_string_or_array(argv, "argv")
	for _, s in ipairs(av) do
		args[#args + 1] = s
	end
	return _cmd.cmd(table.unpack(args))
end

return {
	Mv = Mv,
}
