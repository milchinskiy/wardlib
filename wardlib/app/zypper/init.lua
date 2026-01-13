---@diagnostic disable: undefined-doc-name

-- zypper wrapper module (openSUSE / SUSE Linux Enterprise)
--
-- Thin wrappers around `zypper` that construct CLI invocations and return
-- `ward.process.cmd(...)` objects.
--
-- This module intentionally does not parse output.

local _cmd = require("ward.process")
local validate = require("wardlib.util.validate")
local ensure = require("wardlib.tools.ensure")
local args_util = require("wardlib.util.args")

---@class ZypperCommonOpts
---@field sudo boolean? Prefix the command with `sudo`
---@field non_interactive boolean? `-n, --non-interactive`
---@field quiet boolean? `-q`
---@field verbose boolean? `-v`
---@field refresh boolean? `--refresh`
---@field no_refresh boolean? `--no-refresh`
---@field auto_agree_with_licenses boolean? `--auto-agree-with-licenses`
---@field gpg_auto_import_keys boolean? `--gpg-auto-import-keys`
---@field no_gpg_checks boolean? `--no-gpg-checks`
---@field repos string|string[]? `-r <alias>` (repeatable)
---@field extra string[]? Extra args appended after modeled options

---@class Zypper
---@field bin string Executable name or path to `zypper`
---@field sudo_bin string Executable name or path to `sudo`
---@field cmd fun(subcmd: string, argv: string[]|nil, opts: ZypperCommonOpts|nil): ward.Cmd
---@field refresh fun(opts: ZypperCommonOpts|nil): ward.Cmd
---@field install fun(pkgs: string|string[], opts: ZypperCommonOpts|nil): ward.Cmd
---@field remove fun(pkgs: string|string[], opts: ZypperCommonOpts|nil): ward.Cmd
---@field update fun(pkgs: string|string[]|nil, opts: ZypperCommonOpts|nil): ward.Cmd
---@field dup fun(opts: ZypperCommonOpts|nil): ward.Cmd Dist-upgrade (`dup`)
---@field search fun(term: string, opts: ZypperCommonOpts|nil): ward.Cmd
---@field info fun(pkgs: string|string[], opts: ZypperCommonOpts|nil): ward.Cmd
---@field repos_list fun(opts: ZypperCommonOpts|nil): ward.Cmd List repos (`repos`)
---@field addrepo fun(uri: string, alias: string, opts: ZypperCommonOpts|nil): ward.Cmd
---@field removerepo fun(alias: string, opts: ZypperCommonOpts|nil): ward.Cmd
---@field raw fun(argv: string|string[], opts: ZypperCommonOpts|nil): ward.Cmd
local Zypper = {
	bin = "zypper",
	sudo_bin = "sudo",
}

---@param args string[]
---@param opts ZypperCommonOpts|nil
local function apply_common(args, opts)
	opts = opts or {}

	if opts.refresh and opts.no_refresh then
		error("refresh and no_refresh are mutually exclusive")
	end

	args_util
		.parser(args, opts)
		:flag("non_interactive", "--non-interactive")
		:flag("quiet", "-q")
		:flag("verbose", "-v")
		:flag("refresh", "--refresh")
		:flag("no_refresh", "--no-refresh")
		:flag("auto_agree_with_licenses", "--auto-agree-with-licenses")
		:flag("gpg_auto_import_keys", "--gpg-auto-import-keys")
		:flag("no_gpg_checks", "--no-gpg-checks")
		:repeatable("repos", "-r", { validate = validate.not_flag })
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
---@param opts ZypperCommonOpts|nil
---@return ward.Cmd
function Zypper.cmd(subcmd, argv, opts)
	ensure.bin(Zypper.bin, { label = "zypper binary" })
	opts = opts or {}
	assert(type(subcmd) == "string" and #subcmd > 0, "subcmd must be a non-empty string")

	local args = {}
	if opts.sudo then
		ensure.bin(Zypper.sudo_bin, { label = "sudo binary" })
		args[#args + 1] = Zypper.sudo_bin
	end
	args[#args + 1] = Zypper.bin
	apply_common(args, opts)
	args[#args + 1] = subcmd
	if argv ~= nil then
		for _, s in ipairs(argv) do
			args[#args + 1] = s
		end
	end
	return _cmd.cmd(table.unpack(args))
end

---`zypper refresh`
---@param opts ZypperCommonOpts|nil
---@return ward.Cmd
function Zypper.refresh(opts)
	return Zypper.cmd("refresh", nil, opts)
end

---`zypper install <pkgs...>`
---@param pkgs string|string[]
---@param opts ZypperCommonOpts|nil
---@return ward.Cmd
function Zypper.install(pkgs, opts)
	return Zypper.cmd("install", normalize_list(pkgs, "pkgs"), opts)
end

---`zypper remove <pkgs...>`
---@param pkgs string|string[]
---@param opts ZypperCommonOpts|nil
---@return ward.Cmd
function Zypper.remove(pkgs, opts)
	return Zypper.cmd("remove", normalize_list(pkgs, "pkgs"), opts)
end

---`zypper update [pkgs...]`
---@param pkgs string|string[]|nil
---@param opts ZypperCommonOpts|nil
---@return ward.Cmd
function Zypper.update(pkgs, opts)
	local argv = nil
	if pkgs ~= nil then
		argv = normalize_list(pkgs, "pkgs")
	end
	return Zypper.cmd("update", argv, opts)
end

---`zypper dup`
---@param opts ZypperCommonOpts|nil
---@return ward.Cmd
function Zypper.dup(opts)
	return Zypper.cmd("dup", nil, opts)
end

---`zypper search <term>`
---@param term string
---@param opts ZypperCommonOpts|nil
---@return ward.Cmd
function Zypper.search(term, opts)
	validate.non_empty_string(term, "term")
	return Zypper.cmd("search", { term }, opts)
end

---`zypper info <pkgs...>`
---@param pkgs string|string[]
---@param opts ZypperCommonOpts|nil
---@return ward.Cmd
function Zypper.info(pkgs, opts)
	return Zypper.cmd("info", normalize_list(pkgs, "pkgs"), opts)
end

---List configured repositories.
---Builds: `zypper repos`
---@param opts ZypperCommonOpts|nil
---@return ward.Cmd
function Zypper.repos_list(opts)
	return Zypper.cmd("repos", nil, opts)
end

---Add a repository.
---Builds: `zypper addrepo <uri> <alias>`
---@param uri string
---@param alias string
---@param opts ZypperCommonOpts|nil
---@return ward.Cmd
function Zypper.addrepo(uri, alias, opts)
	validate.non_empty_string(uri, "uri")
	validate.non_empty_string(alias, "alias")
	return Zypper.cmd("addrepo", { uri, alias }, opts)
end

---Remove a repository.
---Builds: `zypper removerepo <alias>`
---@param alias string
---@param opts ZypperCommonOpts|nil
---@return ward.Cmd
function Zypper.removerepo(alias, opts)
	validate.non_empty_string(alias, "alias")
	return Zypper.cmd("removerepo", { alias }, opts)
end

---Low-level escape hatch.
---Builds: `zypper <modeled-opts...> <argv...>`
---@param argv string|string[]
---@param opts ZypperCommonOpts|nil
---@return ward.Cmd
function Zypper.raw(argv, opts)
	ensure.bin(Zypper.bin, { label = "zypper binary" })
	local args = { Zypper.bin }
	apply_common(args, opts)
	local av = args_util.normalize_string_or_array(argv, "argv")
	for _, s in ipairs(av) do
		args[#args + 1] = s
	end
	return _cmd.cmd(table.unpack(args))
end

return {
	Zypper = Zypper,
}
