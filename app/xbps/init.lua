---@diagnostic disable: undefined-doc-name

-- xbps wrapper module (Void Linux)
--
-- Thin wrappers around XBPS tools that construct CLI invocations and return
-- `ward.process.cmd(...)` objects.
--
-- Binaries:
--   * xbps-install
--   * xbps-remove
--   * xbps-query

local _cmd = require("ward.process")
local _env = require("ward.env")
local _fs = require("ward.fs")

---@class XbpsCommonOpts
---@field sudo boolean? Prefix with `sudo`
---@field extra string[]? Extra args appended after options
---@field rootdir string? Add `-r <dir>`
---@field config string? Add `-C <dir>`
---@field cachedir string? Add `-c <dir>`
---@field repositories string[]? Add `--repository <url>` repeated

---@class XbpsInstallOpts: XbpsCommonOpts
---@field yes boolean? Add `-y`
---@field automatic boolean? Add `-A` (mark packages as automatically installed)
---@field force boolean? Add `-f`

---@class XbpsRemoveOpts: XbpsCommonOpts
---@field yes boolean? Add `-y`
---@field recursive boolean? Add `-R`
---@field force boolean? Add `-f`
---@field dry_run boolean? Add `-n`

---@class XbpsSearchOpts: XbpsCommonOpts
---@field regex boolean? Add `--regex`

---@class Xbps
---@field install_bin string
---@field remove_bin string
---@field query_bin string
---@field sudo_bin string
---@field install fun(pkgs: string|string[], opts: XbpsInstallOpts|nil): ward.Cmd
---@field sync fun(opts: XbpsCommonOpts|nil): ward.Cmd
---@field upgrade fun(opts: XbpsInstallOpts|nil): ward.Cmd
---@field remove fun(pkgs: string|string[], opts: XbpsRemoveOpts|nil): ward.Cmd
---@field remove_orphans fun(opts: XbpsRemoveOpts|nil): ward.Cmd
---@field clean_cache fun(opts: XbpsRemoveOpts|nil, all: boolean|nil): ward.Cmd
---@field search fun(pattern: string, opts: XbpsSearchOpts|nil): ward.Cmd
---@field info fun(pkg: string, opts: XbpsCommonOpts|nil): ward.Cmd
---@field list_installed fun(opts: XbpsCommonOpts|nil): ward.Cmd
---@field list_manual fun(opts: XbpsCommonOpts|nil): ward.Cmd
local Xbps = {
	install_bin = "xbps-install",
	remove_bin = "xbps-remove",
	query_bin = "xbps-query",
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
---@param opts XbpsCommonOpts|nil
local function apply_common(args, opts)
	opts = opts or {}
	if opts.rootdir ~= nil then
		validate_non_empty_string(opts.rootdir, "rootdir")
		table.insert(args, "-r")
		table.insert(args, opts.rootdir)
	end
	if opts.config ~= nil then
		validate_non_empty_string(opts.config, "config")
		table.insert(args, "-C")
		table.insert(args, opts.config)
	end
	if opts.cachedir ~= nil then
		validate_non_empty_string(opts.cachedir, "cachedir")
		table.insert(args, "-c")
		table.insert(args, opts.cachedir)
	end
	if opts.repositories ~= nil then
		assert(type(opts.repositories) == "table", "repositories must be an array")
		for _, url in ipairs(opts.repositories) do
			validate_non_empty_string(url, "repository")
			table.insert(args, "--repository")
			table.insert(args, url)
		end
	end
	if opts.extra ~= nil then
		assert(type(opts.extra) == "table", "extra must be an array")
		for _, v in ipairs(opts.extra) do
			table.insert(args, tostring(v))
		end
	end
end

---@param bin string
---@param label string
---@param argv string[]
---@param opts XbpsCommonOpts|nil
---@return ward.Cmd
local function build(bin, label, argv, opts)
	validate_bin(bin, label)
	opts = opts or {}
	local args = {}
	if opts.sudo then
		validate_bin(Xbps.sudo_bin, "sudo")
		table.insert(args, Xbps.sudo_bin)
	end
	table.insert(args, bin)
	for _, v in ipairs(argv) do
		table.insert(args, tostring(v))
	end
	return _cmd.cmd(table.unpack(args))
end

---Install packages: `xbps-install [opts] <pkgs...>`
---@param pkgs string|string[]
---@param opts XbpsInstallOpts|nil
---@return ward.Cmd
function Xbps.install(pkgs, opts)
	opts = opts or {}
	local argv = {}
	apply_common(argv, opts)
	if opts.yes then
		table.insert(argv, "-y")
	end
	if opts.automatic then
		table.insert(argv, "-A")
	end
	if opts.force then
		table.insert(argv, "-f")
	end
	for _, p in ipairs(normalize_pkgs(pkgs)) do
		table.insert(argv, p)
	end
	return build(Xbps.install_bin, "xbps-install", argv, opts)
end

---Synchronize repository indexes: `xbps-install -S`
---@param opts XbpsCommonOpts|nil
---@return ward.Cmd
function Xbps.sync(opts)
	opts = opts or {}
	local argv = {}
	apply_common(argv, opts)
	table.insert(argv, "-S")
	return build(Xbps.install_bin, "xbps-install", argv, opts)
end

---Full system upgrade: `xbps-install -Su`
---@param opts XbpsInstallOpts|nil
---@return ward.Cmd
function Xbps.upgrade(opts)
	opts = opts or {}
	local argv = {}
	apply_common(argv, opts)
	if opts.yes then
		table.insert(argv, "-y")
	end
	table.insert(argv, "-Su")
	if opts.force then
		table.insert(argv, "-f")
	end
	return build(Xbps.install_bin, "xbps-install", argv, opts)
end

---Remove packages: `xbps-remove [opts] <pkgs...>`
---@param pkgs string|string[]
---@param opts XbpsRemoveOpts|nil
---@return ward.Cmd
function Xbps.remove(pkgs, opts)
	opts = opts or {}
	local argv = {}
	apply_common(argv, opts)
	if opts.yes then
		table.insert(argv, "-y")
	end
	if opts.recursive then
		table.insert(argv, "-R")
	end
	if opts.force then
		table.insert(argv, "-f")
	end
	if opts.dry_run then
		table.insert(argv, "-n")
	end
	for _, p in ipairs(normalize_pkgs(pkgs)) do
		table.insert(argv, p)
	end
	return build(Xbps.remove_bin, "xbps-remove", argv, opts)
end

---Remove orphaned packages: `xbps-remove -o`
---@param opts XbpsRemoveOpts|nil
---@return ward.Cmd
function Xbps.remove_orphans(opts)
	opts = opts or {}
	local argv = {}
	apply_common(argv, opts)
	if opts.yes then
		table.insert(argv, "-y")
	end
	table.insert(argv, "-o")
	return build(Xbps.remove_bin, "xbps-remove", argv, opts)
end

---Clean cache: `xbps-remove -O` (twice removes also non-installed from cache)
---@param opts XbpsRemoveOpts|nil
---@param all boolean|nil
---@return ward.Cmd
function Xbps.clean_cache(opts, all)
	opts = opts or {}
	local argv = {}
	apply_common(argv, opts)
	if opts.yes then
		table.insert(argv, "-y")
	end
	if all then
		table.insert(argv, "-OO")
	else
		table.insert(argv, "-O")
	end
	return build(Xbps.remove_bin, "xbps-remove", argv, opts)
end

---Search repositories: `xbps-query -Rs <pattern>`
---@param pattern string
---@param opts XbpsSearchOpts|nil
---@return ward.Cmd
function Xbps.search(pattern, opts)
	opts = opts or {}
	validate_non_empty_string(pattern, "pattern")
	local argv = {}
	apply_common(argv, opts)
	if opts.regex then
		table.insert(argv, "--regex")
	end
	table.insert(argv, "-Rs")
	table.insert(argv, pattern)
	return build(Xbps.query_bin, "xbps-query", argv, opts)
end

---Show info for installed package: `xbps-query -S <pkg>`
---@param pkg string
---@param opts XbpsCommonOpts|nil
---@return ward.Cmd
function Xbps.info(pkg, opts)
	opts = opts or {}
	validate_non_empty_string(pkg, "pkg")
	local argv = {}
	apply_common(argv, opts)
	table.insert(argv, "-S")
	table.insert(argv, pkg)
	return build(Xbps.query_bin, "xbps-query", argv, opts)
end

---List installed packages: `xbps-query -l`
---@param opts XbpsCommonOpts|nil
---@return ward.Cmd
function Xbps.list_installed(opts)
	opts = opts or {}
	local argv = {}
	apply_common(argv, opts)
	table.insert(argv, "-l")
	return build(Xbps.query_bin, "xbps-query", argv, opts)
end

---List manually installed packages: `xbps-query -m`
---@param opts XbpsCommonOpts|nil
---@return ward.Cmd
function Xbps.list_manual(opts)
	opts = opts or {}
	local argv = {}
	apply_common(argv, opts)
	table.insert(argv, "-m")
	return build(Xbps.query_bin, "xbps-query", argv, opts)
end

return {
	Xbps = Xbps,
}
