---@diagnostic disable: undefined-doc-name

-- unzip wrapper module
--
-- Thin wrappers around `unzip` (Info-ZIP) that construct CLI invocations and
-- return `ward.process.cmd(...)` objects.
--
-- This module intentionally does not parse output.
--
-- Note: Info-ZIP `unzip` does NOT support `--` as "end of options".
-- As a result, this wrapper validates that the zip path (and optional file list)
-- do not start with '-'.

local _cmd = require("ward.process")
local validate = require("util.validate")
local args_util = require("util.args")

---@class UnzipOpts
---@field to string? Destination directory (`-d <dir>`)
---@field files string|string[]? Optional file list to extract
---@field exclude string|string[]? Exclude patterns appended after `-x`
---@field overwrite boolean? `-o`
---@field never_overwrite boolean? `-n`
---@field quiet boolean? `-q`
---@field junk_paths boolean? `-j`
---@field list boolean? `-l`
---@field test boolean? `-t`
---@field password string? `-P <password>` (note: insecure on multi-user systems)
---@field extra string[]? Extra args appended after modeled options

---@class Unzip
---@field bin string Executable name or path to `unzip`
---@field extract fun(zip_path: string, opts: UnzipOpts|nil): ward.Cmd
---@field list fun(zip_path: string, opts: UnzipOpts|nil): ward.Cmd
---@field test fun(zip_path: string, opts: UnzipOpts|nil): ward.Cmd
---@field raw fun(argv: string|string[], opts: UnzipOpts|nil): ward.Cmd
local Unzip = {
	bin = "unzip",
}

---@param args string[]
---@param opts UnzipOpts|nil
local function apply_opts(args, opts)
	opts = opts or {}

	if opts.overwrite and opts.never_overwrite then
		error("overwrite and never_overwrite are mutually exclusive")
	end

	if opts.overwrite then
		args[#args + 1] = "-o"
	end
	if opts.never_overwrite then
		args[#args + 1] = "-n"
	end
	if opts.quiet then
		args[#args + 1] = "-q"
	end
	if opts.junk_paths then
		args[#args + 1] = "-j"
	end
	if opts.list then
		args[#args + 1] = "-l"
	end
	if opts.test then
		args[#args + 1] = "-t"
	end
	if opts.password ~= nil then
		validate.non_empty_string(opts.password, "password")
		args[#args + 1] = "-P"
		args[#args + 1] = opts.password
	end

	args_util.append_extra(args, opts.extra)
end

---@param zip_path string
---@param opts UnzipOpts|nil
---@return ward.Cmd
local function build(zip_path, opts)
	validate.bin(Unzip.bin, "unzip binary")
	validate.not_flag(zip_path, "zip_path")
	opts = opts or {}

	local args = { Unzip.bin }
	apply_opts(args, opts)

	-- unzip does not support `--` as end-of-options
	args[#args + 1] = zip_path

	if opts.files ~= nil then
		local files = args_util.normalize_string_or_array(opts.files, "files")
		for _, f in ipairs(files) do
			validate.not_flag(f, "file")
			args[#args + 1] = f
		end
	end

	if opts.exclude ~= nil then
		local excl = args_util.normalize_string_or_array(opts.exclude, "exclude")
		args[#args + 1] = "-x"
		for _, pat in ipairs(excl) do
			args[#args + 1] = pat
		end
	end

	if opts.to ~= nil then
		validate.non_empty_string(opts.to, "to")
		args[#args + 1] = "-d"
		args[#args + 1] = opts.to
	end

	return _cmd.cmd(table.unpack(args))
end

---Extract files from a zip.
---@param zip_path string
---@param opts UnzipOpts|nil
---@return ward.Cmd
function Unzip.extract(zip_path, opts)
	local o = args_util.clone_opts(opts, { "extra" })
	o.list = false
	o.test = false
	return build(zip_path, o)
end

---List zip contents (`unzip -l`).
---@param zip_path string
---@param opts UnzipOpts|nil
---@return ward.Cmd
function Unzip.list(zip_path, opts)
	local o = args_util.clone_opts(opts, { "extra" })
	o.list = true
	o.test = false
	return build(zip_path, o)
end

---Test zip integrity (`unzip -t`).
---@param zip_path string
---@param opts UnzipOpts|nil
---@return ward.Cmd
function Unzip.test(zip_path, opts)
	local o = args_util.clone_opts(opts, { "extra" })
	o.test = true
	o.list = false
	return build(zip_path, o)
end

---Low-level escape hatch.
---Builds: `unzip <modeled-opts...> <argv...>`
---@param argv string|string[]
---@param opts UnzipOpts|nil
---@return ward.Cmd
function Unzip.raw(argv, opts)
	validate.bin(Unzip.bin, "unzip binary")
	local args = { Unzip.bin }
	apply_opts(args, opts)
	local av = args_util.normalize_string_or_array(argv, "argv")
	for _, s in ipairs(av) do
		args[#args + 1] = s
	end
	return _cmd.cmd(table.unpack(args))
end

return {
	Unzip = Unzip,
}
