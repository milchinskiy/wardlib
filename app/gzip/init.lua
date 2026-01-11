---@diagnostic disable: undefined-doc-name

-- gzip wrapper module
--
-- Thin wrappers around `gzip` that construct CLI invocations and return
-- `ward.process.cmd(...)` objects.
--
-- This module intentionally does not parse output.

local _cmd = require("ward.process")
local validate = require("util.validate")
local args_util = require("util.args")

---@class GzipOpts
---@field decompress boolean? `-d`
---@field keep boolean? `-k`
---@field force boolean? `-f`
---@field stdout boolean? `-c`
---@field recursive boolean? `-r`
---@field test boolean? `-t`
---@field list boolean? `-l`
---@field verbose boolean? `-v`
---@field quiet boolean? `-q`
---@field suffix string? `-S <suffix>`
---@field level integer? Compression level `-1`..`-9`
---@field extra string[]? Extra args appended after modeled options

---@class Gzip
---@field bin string Executable name or path to `gzip`
---@field run fun(paths: string|string[], opts: GzipOpts|nil): ward.Cmd
---@field compress fun(paths: string|string[], opts: GzipOpts|nil): ward.Cmd
---@field decompress fun(paths: string|string[], opts: GzipOpts|nil): ward.Cmd
---@field raw fun(argv: string|string[], opts: GzipOpts|nil): ward.Cmd
local Gzip = {
	bin = "gzip",
}

---@param args string[]
---@param opts GzipOpts|nil
local function apply_opts(args, opts)
	opts = opts or {}

	if opts.decompress then
		args[#args + 1] = "-d"
	end
	if opts.keep then
		args[#args + 1] = "-k"
	end
	if opts.force then
		args[#args + 1] = "-f"
	end
	if opts.stdout then
		args[#args + 1] = "-c"
	end
	if opts.recursive then
		args[#args + 1] = "-r"
	end
	if opts.test then
		args[#args + 1] = "-t"
	end
	if opts.list then
		args[#args + 1] = "-l"
	end
	if opts.verbose then
		args[#args + 1] = "-v"
	end
	if opts.quiet then
		args[#args + 1] = "-q"
	end
	if opts.suffix ~= nil then
		validate.non_empty_string(opts.suffix, "suffix")
		args[#args + 1] = "-S"
		args[#args + 1] = opts.suffix
	end
	if opts.level ~= nil then
		validate.integer_min(opts.level, "level", 1)
		assert(opts.level <= 9, "level must be <= 9")
		args[#args + 1] = "-" .. tostring(opts.level)
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

---Run gzip with modeled options.
---
---Builds: `gzip <opts...> -- <paths...>`
---@param paths string|string[]
---@param opts GzipOpts|nil
---@return ward.Cmd
function Gzip.run(paths, opts)
	validate.bin(Gzip.bin, "gzip binary")
	local args = { Gzip.bin }
	apply_opts(args, opts)
	args[#args + 1] = "--"
	for _, p in ipairs(normalize_paths(paths)) do
		args[#args + 1] = p
	end
	return _cmd.cmd(table.unpack(args))
end

---Convenience: compression.
---@param paths string|string[]
---@param opts GzipOpts|nil
---@return ward.Cmd
function Gzip.compress(paths, opts)
	local o = args_util.clone_opts(opts, { "extra" })
	o.decompress = false
	return Gzip.run(paths, o)
end

---Convenience: decompression (`gzip -d`).
---@param paths string|string[]
---@param opts GzipOpts|nil
---@return ward.Cmd
function Gzip.decompress(paths, opts)
	local o = args_util.clone_opts(opts, { "extra" })
	o.decompress = true
	return Gzip.run(paths, o)
end

---Low-level escape hatch.
---Builds: `gzip <modeled-opts...> <argv...>`
---@param argv string|string[]
---@param opts GzipOpts|nil
---@return ward.Cmd
function Gzip.raw(argv, opts)
	validate.bin(Gzip.bin, "gzip binary")
	local args = { Gzip.bin }
	apply_opts(args, opts)
	local av = args_util.normalize_string_or_array(argv, "argv")
	for _, s in ipairs(av) do
		args[#args + 1] = s
	end
	return _cmd.cmd(table.unpack(args))
end

return {
	Gzip = Gzip,
}
