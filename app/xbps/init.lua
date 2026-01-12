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
local validate = require("util.validate")
local ensure = require("tools.ensure")
local args_util = require("util.args")

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

--- @param pkgs string|string[]
--- @return string[]
local function normalize_pkgs(pkgs)
	return args_util.normalize_string_or_array(pkgs, "pkg")
end

---@param args string[]
---@param opts XbpsCommonOpts|nil
local function apply_common(args, opts)
	opts = opts or {}
	args_util
		.parser(args, opts)
		:value_string("rootdir", "-r", "rootdir")
		:value_string("config", "-C", "config")
		:value_string("cachedir", "-c", "cachedir")
		:repeatable("repositories", "--repository", { label = "repository", validate = validate.non_empty_string })
		:extra()
end

---@param bin string
---@param label string
---@param argv string[]
---@param opts XbpsCommonOpts|nil
---@return ward.Cmd
local function build(bin, label, argv, opts)
	ensure.bin(bin, { label = tostring(label) .. " binary" })
	opts = opts or {}
	local args = {}
	if opts.sudo then
		ensure.bin(Xbps.sudo_bin, { label = "sudo binary" })
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
	args_util.parser(argv, opts):flag("yes", "-y"):flag("automatic", "-A"):flag("force", "-f")
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
	args_util.parser(argv, opts):flag("yes", "-y")
	argv[#argv + 1] = "-Su"
	args_util.parser(argv, opts):flag("force", "-f")
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
	args_util.parser(argv, opts):flag("yes", "-y"):flag("recursive", "-R"):flag("force", "-f"):flag("dry_run", "-n")
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
	validate.non_empty_string(pattern, "pattern")
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
	validate.non_empty_string(pkg, "pkg")
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
