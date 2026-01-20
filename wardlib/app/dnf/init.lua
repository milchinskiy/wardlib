---@diagnostic disable: undefined-doc-name

-- dnf wrapper module (Fedora / RHEL-family)
--
-- Thin wrappers around `dnf` that construct CLI invocations and return
-- `ward.process.cmd(...)` objects.
--
-- This module intentionally does not parse output.

local _cmd = require("ward.process")
local args_util = require("wardlib.util.args")
local ensure = require("wardlib.tools.ensure")
local validate = require("wardlib.util.validate")

---@class DnfCommonOpts
---@field assume_yes boolean? `-y`
---@field assume_no boolean? `-n`
---@field quiet boolean? `-q`
---@field verbose boolean? `-v`
---@field refresh boolean? `--refresh`
---@field best boolean? `--best`
---@field allowerasing boolean? `--allowerasing`
---@field skip_broken boolean? `--skip-broken`
---@field nogpgcheck boolean? `--nogpgcheck`
---@field cacheonly boolean? `-C, --cacheonly`
---@field releasever string? `--releasever=<ver>`
---@field installroot string? `--installroot=<path>`
---@field enable_repo string|string[]? `--enablerepo=<repoid>` (repeatable)
---@field disable_repo string|string[]? `--disablerepo=<repoid>` (repeatable)
---@field extra string[]? Extra args appended after modeled options

---@class Dnf
---@field bin string Executable name or path to `dnf`
---@field cmd fun(subcmd: string, argv: string[]|nil, opts: DnfCommonOpts|nil): ward.Cmd
---@field install fun(pkgs: string|string[], opts: DnfCommonOpts|nil): ward.Cmd
---@field remove fun(pkgs: string|string[], opts: DnfCommonOpts|nil): ward.Cmd
---@field update fun(pkgs: string|string[]|nil, opts: DnfCommonOpts|nil): ward.Cmd
---@field upgrade fun(pkgs: string|string[]|nil, opts: DnfCommonOpts|nil): ward.Cmd
---@field autoremove fun(opts: DnfCommonOpts|nil): ward.Cmd
---@field makecache fun(opts: DnfCommonOpts|nil): ward.Cmd
---@field search fun(term: string, opts: DnfCommonOpts|nil): ward.Cmd
---@field info fun(pkgs: string|string[], opts: DnfCommonOpts|nil): ward.Cmd
---@field raw fun(argv: string|string[], opts: DnfCommonOpts|nil): ward.Cmd
local Dnf = {
	bin = "dnf",
}

---@param args string[]
---@param opts DnfCommonOpts|nil
local function apply_common(args, opts)
	opts = opts or {}

	if opts.assume_yes and opts.assume_no then error("assume_yes and assume_no are mutually exclusive") end

	args_util
		.parser(args, opts)
		:flag("assume_yes", "-y")
		:flag("assume_no", "-n")
		:flag("quiet", "-q")
		:flag("verbose", "-v")
		:flag("refresh", "--refresh")
		:flag("best", "--best")
		:flag("allowerasing", "--allowerasing")
		:flag("skip_broken", "--skip-broken")
		:flag("nogpgcheck", "--nogpgcheck")
		:flag("cacheonly", "-C")
		:value("releasever", "--releasever", { mode = "equals", validate = validate.non_empty_string })
		:value("installroot", "--installroot", { mode = "equals", validate = validate.non_empty_string })
		:repeatable("enable_repo", "--enablerepo", { mode = "equals", validate = validate.non_empty_string })
		:repeatable("disable_repo", "--disablerepo", { mode = "equals", validate = validate.non_empty_string })
		:extra()
end

---@param v string|string[]
---@param label string
---@return string[]
local function normalize_list(v, label)
	local list = args_util.normalize_string_or_array(v, label)
	assert(#list > 0, label .. " must not be empty")
	for _, s in ipairs(list) do
		validate.not_flag(s, label)
	end
	return list
end

---@param subcmd string
---@param argv string[]|nil
---@param opts DnfCommonOpts|nil
---@return ward.Cmd
function Dnf.cmd(subcmd, argv, opts)
	ensure.bin(Dnf.bin, { label = "dnf binary" })
	opts = opts or {}
	assert(type(subcmd) == "string" and #subcmd > 0, "subcmd must be a non-empty string")

	local args = { Dnf.bin }
	apply_common(args, opts)
	args[#args + 1] = subcmd

	if argv ~= nil then
		for _, s in ipairs(argv) do
			args[#args + 1] = s
		end
	end

	return _cmd.cmd(table.unpack(args))
end

---`dnf install <pkgs...>`
---@param pkgs string|string[]
---@param opts DnfCommonOpts|nil
---@return ward.Cmd
function Dnf.install(pkgs, opts) return Dnf.cmd("install", normalize_list(pkgs, "pkgs"), opts) end

---`dnf remove <pkgs...>`
---@param pkgs string|string[]
---@param opts DnfCommonOpts|nil
---@return ward.Cmd
function Dnf.remove(pkgs, opts) return Dnf.cmd("remove", normalize_list(pkgs, "pkgs"), opts) end

---`dnf update [pkgs...]`
---@param pkgs string|string[]|nil
---@param opts DnfCommonOpts|nil
---@return ward.Cmd
function Dnf.update(pkgs, opts)
	local argv = nil
	if pkgs ~= nil then argv = normalize_list(pkgs, "pkgs") end
	return Dnf.cmd("update", argv, opts)
end

---`dnf upgrade [pkgs...]`
---@param pkgs string|string[]|nil
---@param opts DnfCommonOpts|nil
---@return ward.Cmd
function Dnf.upgrade(pkgs, opts)
	local argv = nil
	if pkgs ~= nil then argv = normalize_list(pkgs, "pkgs") end
	return Dnf.cmd("upgrade", argv, opts)
end

---`dnf autoremove`
---@param opts DnfCommonOpts|nil
---@return ward.Cmd
function Dnf.autoremove(opts) return Dnf.cmd("autoremove", nil, opts) end

---`dnf makecache`
---@param opts DnfCommonOpts|nil
---@return ward.Cmd
function Dnf.makecache(opts) return Dnf.cmd("makecache", nil, opts) end

---`dnf search <term>`
---@param term string
---@param opts DnfCommonOpts|nil
---@return ward.Cmd
function Dnf.search(term, opts)
	validate.non_empty_string(term, "term")
	return Dnf.cmd("search", { term }, opts)
end

---`dnf info <pkgs...>`
---@param pkgs string|string[]
---@param opts DnfCommonOpts|nil
---@return ward.Cmd
function Dnf.info(pkgs, opts) return Dnf.cmd("info", normalize_list(pkgs, "pkgs"), opts) end

---Low-level escape hatch.
---Builds: `dnf <modeled-opts...> <argv...>`
---@param argv string|string[]
---@param opts DnfCommonOpts|nil
---@return ward.Cmd
function Dnf.raw(argv, opts)
	ensure.bin(Dnf.bin, { label = "dnf binary" })
	local args = { Dnf.bin }
	apply_common(args, opts)
	local av = args_util.normalize_string_or_array(argv, "argv")
	for _, s in ipairs(av) do
		args[#args + 1] = s
	end
	return _cmd.cmd(table.unpack(args))
end

return {
	Dnf = Dnf,
}
