---@diagnostic disable: undefined-doc-name

-- apk wrapper module (Alpine Linux)
--
-- Thin wrappers around `apk` that construct CLI invocations and return
-- `ward.process.cmd(...)` objects.
--
-- This module intentionally does not parse output; consumers can decide how to
-- execute returned commands and interpret results.

local _cmd = require("ward.process")
local _env = require("ward.env")
local _fs = require("ward.fs")

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

---@param bin string
---@param label string
local function validate_bin(bin, label)
	assert(type(bin) == "string" and #bin > 0, label .. " binary is not set")
	if bin:find("/", 1, true) then
		assert(_fs.is_exists(bin), string.format("%s binary does not exist: %s", label, bin))
		assert(_fs.is_executable(bin), string.format("%s binary is not executable: %s", label, bin))
	else
		assert(_env.is_in_path(bin), string.format("%s binary is not in PATH: %s", label, bin))
	end
end

---@param s any
---@param label string
local function validate_non_empty_string(s, label)
	assert(type(s) == "string" and #s > 0, label .. " must be a non-empty string")
end

---@param pkgs string|string[]
---@return string[]
local function normalize_pkgs(pkgs)
	if type(pkgs) == "string" then
		validate_non_empty_string(pkgs, "pkg")
		return { pkgs }
	end
	assert(type(pkgs) == "table" and #pkgs > 0, "pkgs must be a non-empty string[]")
	local out = {}
	for _, p in ipairs(pkgs) do
		validate_non_empty_string(p, "pkg")
		table.insert(out, p)
	end
	return out
end

---@param args string[]
---@param opts ApkCommonOpts|nil
local function apply_common(args, opts)
	opts = opts or {}
	if opts.extra ~= nil then
		assert(type(opts.extra) == "table", "extra must be an array")
		for _, v in ipairs(opts.extra) do
			table.insert(args, tostring(v))
		end
	end
end

---@param subcmd string
---@param argv string[]|nil
---@param opts ApkCommonOpts|nil
---@return ward.Cmd
function Apk.cmd(subcmd, argv, opts)
	validate_bin(Apk.bin, "apk")

	opts = opts or {}
	assert(type(subcmd) == "string" and #subcmd > 0, "subcmd must be a non-empty string")

	local args = {}
	if opts.sudo then
		validate_bin(Apk.sudo_bin, "sudo")
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
	if opts.no_cache then
		table.insert(argv, "--no-cache")
	end
	if opts.update_cache then
		table.insert(argv, "--update-cache")
	end
	if opts.virtual ~= nil then
		validate_non_empty_string(opts.virtual, "virtual")
		table.insert(argv, "--virtual")
		table.insert(argv, opts.virtual)
	end
	apply_common(argv, opts)
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
	if opts.rdepends then
		table.insert(argv, "--rdepends")
	end
	apply_common(argv, opts)
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
	validate_non_empty_string(pattern, "pattern")
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
		validate_non_empty_string(pkg, "pkg")
		table.insert(argv, pkg)
	end
	return Apk.cmd("info", argv, opts)
end

return {
	Apk = Apk,
}
