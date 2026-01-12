---@diagnostic disable: undefined-doc-name, undefined-doc-param

-- apk wrapper module (Alpine Linux)
--
-- Thin wrappers around `apk` that construct CLI invocations and return
-- `ward.process.cmd(...)` objects.
--
-- This module intentionally does not parse output; consumers can decide how to
-- execute returned commands and interpret results.

local _cmd = require("ward.process")
local validate = require("util.validate")
local ensure = require("tools.ensure")
local args_util = require("util.args")

---@class ApkCommonOpts
---@field sudo boolean? Prefix with `sudo`
---@field extra string[]? Extra args appended after options

---@class ApkAddOpts: ApkCommonOpts
---@field no_cache boolean? Add `--no-cache`
---@field update_cache boolean? Add `--update-cache`
---@field virtual string? Add `--virtual <name>` (create virtual package)

---@class ApkDelOpts: ApkCommonOpts
---@field rdepends boolean? Add `--rdepends`

---@class Apk
---@field bin string Executable name or path to `apk`
---@field sudo_bin string Executable name or path to `sudo`
---@field cmd fun(subcmd: string, argv: string[]|nil, opts: ApkCommonOpts|nil): ward.Cmd
---@field update fun(opts: ApkCommonOpts|nil): ward.Cmd
---@field upgrade fun(opts: ApkCommonOpts|nil): ward.Cmd
---@field add fun(pkgs: string|string[], opts: ApkAddOpts|nil): ward.Cmd
---@field del fun(pkgs: string|string[], opts: ApkDelOpts|nil): ward.Cmd
---@field search fun(pattern: string, opts: ApkCommonOpts|nil): ward.Cmd
---@field info fun(pkg: string|nil, opts: ApkCommonOpts|nil): ward.Cmd
local Apk = {
	bin = "apk",
	sudo_bin = "sudo",
}

--- @param pkgs string|string[]
--- @return string[]
local function normalize_pkgs(pkgs)
	return args_util.normalize_string_or_array(pkgs, "pkg")
end

---@param args string[]
---@param opts ApkCommonOpts|nil
local function apply_common(args, opts)
	opts = opts or {}
	args_util.parser(args, opts):extra()
end

---@param subcmd string
---@param argv string[]|nil
---@param opts ApkCommonOpts|nil
---@return ward.Cmd
function Apk.cmd(subcmd, argv, opts)
	ensure.bin(Apk.bin, { label = "apk binary" })

	opts = opts or {}
	assert(type(subcmd) == "string" and #subcmd > 0, "subcmd must be a non-empty string")

	local args = {}
	if opts.sudo then
		ensure.bin(Apk.sudo_bin, { label = "sudo binary" })
		table.insert(args, Apk.sudo_bin)
	end

	table.insert(args, Apk.bin)
	table.insert(args, subcmd)
	if argv ~= nil then
		for _, v in ipairs(argv) do
			table.insert(args, tostring(v))
		end
	end
	return _cmd.cmd(table.unpack(args))
end

---`apk update`
---@param opts ApkCommonOpts|nil
---@return ward.Cmd
function Apk.update(opts)
	opts = opts or {}
	local argv = {}
	apply_common(argv, opts)
	return Apk.cmd("update", argv, opts)
end

---`apk upgrade`
---@param opts ApkCommonOpts|nil
---@return ward.Cmd
function Apk.upgrade(opts)
	opts = opts or {}
	local argv = {}
	apply_common(argv, opts)
	return Apk.cmd("upgrade", argv, opts)
end

---`apk add ...`
---@param pkgs string|string[]
---@param opts ApkAddOpts|nil
---@return ward.Cmd
function Apk.add(pkgs, opts)
	opts = opts or {}
	local argv = {}
	args_util
		.parser(argv, opts)
		:flag("no_cache", "--no-cache")
		:flag("update_cache", "--update-cache")
		:value_string("virtual", "--virtual", "virtual")
		:extra()
	for _, p in ipairs(normalize_pkgs(pkgs)) do
		table.insert(argv, p)
	end
	return Apk.cmd("add", argv, opts)
end

---`apk del ...`
---@param pkgs string|string[]
---@param opts ApkDelOpts|nil
---@return ward.Cmd
function Apk.del(pkgs, opts)
	opts = opts or {}
	local argv = {}
	args_util.parser(argv, opts):flag("rdepends", "--rdepends"):extra()
	for _, p in ipairs(normalize_pkgs(pkgs)) do
		table.insert(argv, p)
	end
	return Apk.cmd("del", argv, opts)
end

---`apk search <pattern>`
---@param pattern string
---@param opts ApkCommonOpts|nil
---@return ward.Cmd
function Apk.search(pattern, opts)
	opts = opts or {}
	validate.non_empty_string(pattern, "pattern")
	local argv = {}
	apply_common(argv, opts)
	table.insert(argv, pattern)
	return Apk.cmd("search", argv, opts)
end

---`apk info [pkg]` (if pkg is nil, shows all installed packages)
---@param pkg string|nil
---@param opts ApkCommonOpts|nil
---@return ward.Cmd
function Apk.info(pkg, opts)
	opts = opts or {}
	local argv = {}
	apply_common(argv, opts)
	if pkg ~= nil then
		validate.non_empty_string(pkg, "pkg")
		table.insert(argv, pkg)
	end
	return Apk.cmd("info", argv, opts)
end

return {
	Apk = Apk,
}
