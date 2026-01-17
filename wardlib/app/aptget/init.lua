---@diagnostic disable: undefined-doc-name

-- apt-get wrapper module (Debian/Ubuntu)
--
-- Thin wrappers around `apt-get` that construct CLI invocations and return
-- `ward.process.cmd(...)` objects.
--
-- Note: APT often requires root. This module supports `opts.sudo = true` to
-- prefix commands with `sudo`.

local _cmd = require("ward.process")
local args_util = require("wardlib.util.args")
local ensure = require("wardlib.tools.ensure")

---@class AptGetCommonOpts
---@field sudo boolean? Prefix with `sudo`
---@field extra string[]? Extra args appended after options
---@field assume_yes boolean? Add `-y`
---@field quiet boolean|integer? Add `-q` or `-qq` (true/1 => -q, 2 => -qq)

---@class AptGetInstallOpts: AptGetCommonOpts
---@field no_install_recommends boolean? Add `--no-install-recommends`

---@class AptGetRemoveOpts: AptGetCommonOpts
---@field purge boolean? Use `purge` instead of `remove`

---@class AptGet
---@field bin string
---@field sudo_bin string
---@field cmd fun(subcmd: string, argv: string[]|nil, opts: AptGetCommonOpts|nil): ward.Cmd
---@field update fun(opts: AptGetCommonOpts|nil): ward.Cmd
---@field upgrade fun(opts: AptGetCommonOpts|nil): ward.Cmd
---@field dist_upgrade fun(opts: AptGetCommonOpts|nil): ward.Cmd
---@field install fun(pkgs: string|string[], opts: AptGetInstallOpts|nil): ward.Cmd
---@field remove fun(pkgs: string|string[], opts: AptGetRemoveOpts|nil): ward.Cmd
---@field autoremove fun(opts: AptGetCommonOpts|nil): ward.Cmd
---@field clean fun(opts: AptGetCommonOpts|nil): ward.Cmd
local AptGet = {
	bin = "apt-get",
	sudo_bin = "sudo",
}

--- @param pkgs string|string[]
--- @return string[]
local function normalize_pkgs(pkgs) return args_util.normalize_string_or_array(pkgs, "pkg") end

---@param args string[]
---@param opts AptGetCommonOpts|nil
local function apply_common(args, opts)
	opts = opts or {}

	-- quiet is special: APT supports `-q` and combined `-qq`.
	if opts.quiet ~= nil then
		local lvl
		if opts.quiet == true then
			lvl = 1
		elseif type(opts.quiet) == "number" then
			---@diagnostic disable-next-line: param-type-mismatch
			lvl = math.floor(opts.quiet)
		elseif opts.quiet == false then
			lvl = 0
		else
			lvl = 0
		end
		if lvl >= 2 then
			table.insert(args, "-qq")
		elseif lvl == 1 then
			table.insert(args, "-q")
		end
	end

	args_util.parser(args, opts):flag("assume_yes", "-y"):extra()
end

---@param subcmd string
---@param argv string[]|nil
---@param opts AptGetCommonOpts|nil
---@return ward.Cmd
function AptGet.cmd(subcmd, argv, opts)
	ensure.bin(AptGet.bin, { label = "apt-get binary" })

	opts = opts or {}
	assert(type(subcmd) == "string" and #subcmd > 0, "subcmd must be a non-empty string")

	local args = {}
	if opts.sudo then
		ensure.bin(AptGet.sudo_bin, { label = "sudo binary" })
		table.insert(args, AptGet.sudo_bin)
	end

	table.insert(args, AptGet.bin)
	apply_common(args, opts)
	table.insert(args, subcmd)
	if argv ~= nil then
		for _, v in ipairs(argv) do
			table.insert(args, tostring(v))
		end
	end
	return _cmd.cmd(table.unpack(args))
end

---`apt-get update`
---@param opts AptGetCommonOpts|nil
---@return ward.Cmd
function AptGet.update(opts) return AptGet.cmd("update", nil, opts) end

---`apt-get upgrade`
---@param opts AptGetCommonOpts|nil
---@return ward.Cmd
function AptGet.upgrade(opts) return AptGet.cmd("upgrade", nil, opts) end

---`apt-get dist-upgrade`
---@param opts AptGetCommonOpts|nil
---@return ward.Cmd
function AptGet.dist_upgrade(opts) return AptGet.cmd("dist-upgrade", nil, opts) end

---`apt-get install ...`
---@param pkgs string|string[]
---@param opts AptGetInstallOpts|nil
---@return ward.Cmd
function AptGet.install(pkgs, opts)
	opts = opts or {}
	local argv = {}
	args_util.parser(argv, opts):flag("no_install_recommends", "--no-install-recommends")
	for _, p in ipairs(normalize_pkgs(pkgs)) do
		table.insert(argv, p)
	end
	return AptGet.cmd("install", argv, opts)
end

---`apt-get remove|purge ...`
---@param pkgs string|string[]
---@param opts AptGetRemoveOpts|nil
---@return ward.Cmd
function AptGet.remove(pkgs, opts)
	opts = opts or {}
	local argv = {}
	for _, p in ipairs(normalize_pkgs(pkgs)) do
		table.insert(argv, p)
	end
	local subcmd = opts.purge and "purge" or "remove"
	return AptGet.cmd(subcmd, argv, opts)
end

---`apt-get autoremove`
---@param opts AptGetCommonOpts|nil
---@return ward.Cmd
function AptGet.autoremove(opts) return AptGet.cmd("autoremove", nil, opts) end

---`apt-get clean`
---@param opts AptGetCommonOpts|nil
---@return ward.Cmd
function AptGet.clean(opts) return AptGet.cmd("clean", nil, opts) end

return {
	AptGet = AptGet,
}
