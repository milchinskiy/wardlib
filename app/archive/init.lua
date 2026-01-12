---@diagnostic disable: undefined-doc-name

-- archive (tar) wrapper module
--
-- Thin wrappers around `tar` that construct CLI invocations and return
-- `ward.process.cmd(...)` objects.
--
-- Supported operations:
--   * create: tar -c
--   * extract: tar -x
--   * list: tar -t
--
-- The module does not parse output.

local _cmd = require("ward.process")
local validate = require("util.validate")
local ensure = require("tools.ensure")
local args_util = require("util.args")

---@class ArchiveCommonOpts
---@field dir string? For create: `-C <dir>` before the input paths
---@field verbose boolean? `-v`
---@field compression "gz"|"xz"|"zstd"|nil Compression flag (`-z`, `-J`, `--zstd`)
---@field extra string[]? Extra args appended after options (before paths)

---@class ArchiveExtractOpts: ArchiveCommonOpts
---@field to string? Destination directory (`-C <to>`) for extract
---@field strip_components integer? `--strip-components=<n>`

---@class Archive
---@field bin string Executable name or path to `tar`
---@field create fun(archive_path: string, inputs: string[] , opts: ArchiveCommonOpts|nil): ward.Cmd
---@field extract fun(archive_path: string, opts: ArchiveExtractOpts|nil): ward.Cmd
---@field list fun(archive_path: string, opts: ArchiveCommonOpts|nil): ward.Cmd
local Archive = {
	bin = "tar",
}

---@param args string[]
---@param opts ArchiveCommonOpts|nil
---@param allow_dir boolean
---@param for_extract boolean
local function apply_common(args, opts, allow_dir, for_extract)
	opts = opts or {}

	if opts.verbose then
		table.insert(args, "-v")
	end

	if opts.compression ~= nil then
		local c = opts.compression
		if c == "gz" then
			table.insert(args, "-z")
		elseif c == "xz" then
			table.insert(args, "-J")
		elseif c == "zstd" then
			table.insert(args, "--zstd")
		else
			error("unsupported compression: " .. tostring(c))
		end
	end

	if allow_dir and opts.dir ~= nil and not for_extract then
		validate.non_empty_string(opts.dir, "dir")
		table.insert(args, "-C")
		table.insert(args, opts.dir)
	end

	args_util.append_extra(args, opts.extra)
end

---Create archive from inputs.
---@param archive_path string
---@param inputs string[]
---@param opts ArchiveCommonOpts|nil
---@return ward.Cmd
function Archive.create(archive_path, inputs, opts)
	ensure.bin(Archive.bin, { label = 'tar binary' })
	validate.non_empty_string(archive_path, "archive_path")
	assert(type(inputs) == "table" and #inputs > 0, "inputs must be a non-empty array")

	local args = { Archive.bin, "-c" }
	apply_common(args, opts, true, false)
	table.insert(args, "-f")
	table.insert(args, archive_path)

	for _, p in ipairs(inputs) do
		validate.non_empty_string(p, "input")
		table.insert(args, p)
	end

	return _cmd.cmd(table.unpack(args))
end

---Extract archive.
---@param archive_path string
---@param opts ArchiveExtractOpts|nil
---@return ward.Cmd
function Archive.extract(archive_path, opts)
	ensure.bin(Archive.bin, { label = 'tar binary' })
	validate.non_empty_string(archive_path, "archive_path")
	opts = opts or {}

	local args = { Archive.bin, "-x" }
	apply_common(args, opts, false, true)
	table.insert(args, "-f")
	table.insert(args, archive_path)

	if opts.strip_components ~= nil then
		validate.integer_non_negative(opts.strip_components, "strip_components")
		table.insert(args, "--strip-components=" .. tostring(opts.strip_components))
	end

	if opts.to ~= nil then
		validate.non_empty_string(opts.to, "to")
		table.insert(args, "-C")
		table.insert(args, opts.to)
	end

	return _cmd.cmd(table.unpack(args))
end

---List archive contents.
---@param archive_path string
---@param opts ArchiveCommonOpts|nil
---@return ward.Cmd
function Archive.list(archive_path, opts)
	ensure.bin(Archive.bin, { label = 'tar binary' })
	validate.non_empty_string(archive_path, "archive_path")

	local args = { Archive.bin, "-t" }
	apply_common(args, opts, false, false)
	table.insert(args, "-f")
	table.insert(args, archive_path)
	return _cmd.cmd(table.unpack(args))
end

return {
	Archive = Archive,
}
