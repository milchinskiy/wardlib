---@diagnostic disable: undefined-doc-name

-- xz wrapper module
--
-- Thin wrappers around `xz` that construct CLI invocations and return
-- `ward.process.cmd(...)` objects.
--
-- This module intentionally does not parse output.

local _cmd = require("ward.process")
local args_util = require("wardlib.util.args")
local ensure = require("wardlib.tools.ensure")
local validate = require("wardlib.util.validate")

---@class XzOpts
---@field decompress boolean? `-d`
---@field keep boolean? `-k`
---@field force boolean? `-f`
---@field stdout boolean? `-c`
---@field verbose boolean? `-v`
---@field quiet boolean? `-q`
---@field extreme boolean? `-e`
---@field level integer? Compression level `-0`..`-9`
---@field threads integer? `-T <n>` (0 = auto)
---@field extra string[]? Extra args appended after modeled options

---@class Xz
---@field bin string Executable name or path to `xz`
---@field run fun(paths: string|string[], opts: XzOpts|nil): ward.Cmd
---@field compress fun(paths: string|string[], opts: XzOpts|nil): ward.Cmd
---@field decompress fun(paths: string|string[], opts: XzOpts|nil): ward.Cmd
---@field raw fun(argv: string|string[], opts: XzOpts|nil): ward.Cmd
local Xz = {
	bin = "xz",
}

---@param args string[]
---@param opts XzOpts|nil
local function apply_opts(args, opts)
	opts = opts or {}

	local p = args_util.parser(args, opts)
	p:flag("decompress", "-d")
		:flag("keep", "-k")
		:flag("force", "-f")
		:flag("stdout", "-c")
		:flag("verbose", "-v")
		:flag("quiet", "-q")
		:flag("extreme", "-e")

	if opts.level ~= nil then
		validate.integer_min(opts.level, "level", 0)
		assert(opts.level <= 9, "level must be <= 9")
		args[#args + 1] = "-" .. tostring(opts.level)
	end

	p:value_number("threads", "-T", { integer = true, non_negative = true })
	p:extra()
end

---@param paths string|string[]
---@return string[]
local function normalize_paths(paths)
	local list = args_util.normalize_string_or_array(paths, "paths")
	assert(#list > 0, "paths must not be empty")
	return list
end

---Run xz with modeled options.
---
---Builds: `xz <opts...> -- <paths...>`
---@param paths string|string[]
---@param opts XzOpts|nil
---@return ward.Cmd
function Xz.run(paths, opts)
	ensure.bin(Xz.bin, { label = "xz binary" })
	local args = { Xz.bin }
	apply_opts(args, opts)
	args[#args + 1] = "--"
	for _, p in ipairs(normalize_paths(paths)) do
		args[#args + 1] = p
	end
	return _cmd.cmd(table.unpack(args))
end

---Convenience: compression.
---@param paths string|string[]
---@param opts XzOpts|nil
---@return ward.Cmd
function Xz.compress(paths, opts)
	local o = args_util.clone_opts(opts, { "extra" })
	o.decompress = false
	return Xz.run(paths, o)
end

---Convenience: decompression (`xz -d`).
---@param paths string|string[]
---@param opts XzOpts|nil
---@return ward.Cmd
function Xz.decompress(paths, opts)
	local o = args_util.clone_opts(opts, { "extra" })
	o.decompress = true
	return Xz.run(paths, o)
end

---Low-level escape hatch.
---Builds: `xz <modeled-opts...> <argv...>`
---@param argv string|string[]
---@param opts XzOpts|nil
---@return ward.Cmd
function Xz.raw(argv, opts)
	ensure.bin(Xz.bin, { label = "xz binary" })
	local args = { Xz.bin }
	apply_opts(args, opts)
	local av = args_util.normalize_string_or_array(argv, "argv")
	for _, s in ipairs(av) do
		args[#args + 1] = s
	end
	return _cmd.cmd(table.unpack(args))
end

return {
	Xz = Xz,
}
