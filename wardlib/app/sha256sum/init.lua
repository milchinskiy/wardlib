---@diagnostic disable: undefined-doc-name

-- sha256sum wrapper module
--
-- Thin wrappers around `sha256sum` that construct CLI invocations and return
-- `ward.process.cmd(...)` objects.
--
-- This module intentionally does not parse output.

local _cmd = require("ward.process")
local ensure = require("wardlib.tools.ensure")
local args_util = require("wardlib.util.args")

---@class Sha256sumOpts
---@field binary boolean? `-b` (read files in binary mode)
---@field text boolean? `-t` (read files in text mode)
---@field tag boolean? `--tag`
---@field zero boolean? `-z` (line ends with NUL, not newline)
---@field quiet boolean? `--quiet` (check mode)
---@field status boolean? `--status` (check mode)
---@field warn boolean? `-w, --warn` (check mode)
---@field strict boolean? `--strict` (check mode)
---@field ignore_missing boolean? `--ignore-missing` (check mode)
---@field extra string[]? Extra args appended after modeled options

---@class Sha256sum
---@field bin string Executable name or path to `sha256sum`
---@field sum fun(files: string|string[]|nil, opts: Sha256sumOpts|nil): ward.Cmd
---@field check fun(check_files: string|string[]|nil, opts: Sha256sumOpts|nil): ward.Cmd
---@field raw fun(argv: string|string[], opts: Sha256sumOpts|nil): ward.Cmd
local Sha256sum = {
	bin = "sha256sum",
}

---@param args string[]
---@param opts Sha256sumOpts|nil
local function apply_opts(args, opts)
	opts = opts or {}

	if opts.binary and opts.text then
		error("binary and text are mutually exclusive")
	end

	args_util
		.parser(args, opts)
		:flag("binary", "-b")
		:flag("text", "-t")
		:flag("tag", "--tag")
		:flag("zero", "-z")
		:flag("quiet", "--quiet")
		:flag("status", "--status")
		:flag("warn", "--warn")
		:flag("strict", "--strict")
		:flag("ignore_missing", "--ignore-missing")
		:extra()
end

---@param files string|string[]|nil
---@param label string
---@return string[]|nil
local function normalize_files_opt(files, label)
	if files == nil then
		return nil
	end
	local list = args_util.normalize_string_or_array(files, label)
	assert(#list > 0, label .. " must not be empty")
	return list
end

---Compute SHA-256 checksums.
---
---Builds: `sha256sum <opts...> [-- <files...>]`
---
---If `files` is nil, sha256sum reads stdin.
---@param files string|string[]|nil
---@param opts Sha256sumOpts|nil
---@return ward.Cmd
function Sha256sum.sum(files, opts)
	ensure.bin(Sha256sum.bin, { label = "sha256sum binary" })
	local args = { Sha256sum.bin }
	apply_opts(args, opts)

	local list = normalize_files_opt(files, "files")
	if list ~= nil then
		args[#args + 1] = "--"
		for _, p in ipairs(list) do
			args[#args + 1] = p
		end
	end

	return _cmd.cmd(table.unpack(args))
end

---Verify SHA-256 checksums.
---
---Builds: `sha256sum -c <opts...> [-- <check_files...>]`
---
---If `check_files` is nil, sha256sum reads the checksum list from stdin.
---@param check_files string|string[]|nil
---@param opts Sha256sumOpts|nil
---@return ward.Cmd
function Sha256sum.check(check_files, opts)
	ensure.bin(Sha256sum.bin, { label = "sha256sum binary" })
	local args = { Sha256sum.bin, "-c" }
	apply_opts(args, opts)

	local list = normalize_files_opt(check_files, "check_files")
	if list ~= nil then
		args[#args + 1] = "--"
		for _, p in ipairs(list) do
			args[#args + 1] = p
		end
	end

	return _cmd.cmd(table.unpack(args))
end

---Low-level escape hatch.
---Builds: `sha256sum <modeled-opts...> <argv...>`
---@param argv string|string[]
---@param opts Sha256sumOpts|nil
---@return ward.Cmd
function Sha256sum.raw(argv, opts)
	ensure.bin(Sha256sum.bin, { label = "sha256sum binary" })
	local args = { Sha256sum.bin }
	apply_opts(args, opts)
	local av = args_util.normalize_string_or_array(argv, "argv")
	for _, s in ipairs(av) do
		args[#args + 1] = s
	end
	return _cmd.cmd(table.unpack(args))
end

return {
	Sha256sum = Sha256sum,
}
