---@diagnostic disable: undefined-doc-name

-- yay wrapper module (AUR helper for Arch Linux)
--
-- Thin wrappers around `yay` that construct CLI invocations and return
-- `ward.process.cmd(...)` objects.
--
-- Note: `yay` largely mirrors pacman flags, but it also builds/install AUR
-- packages. This module focuses on the common package-management flows.

local _cmd = require("ward.process")
local validate = require("util.validate")
local ensure = require("tools.ensure")
local args_util = require("util.args")

---@class YayCommonOpts
---@field sudo boolean? Prefix with `sudo`
---@field extra string[]? Extra args appended after options
---@field noconfirm boolean? Add `--noconfirm`
---@field needed boolean? Add `--needed`

---@class YaySyncOpts: YayCommonOpts
---@field refresh boolean? Add a second `y` (i.e. use `-Syy` / `-Syyu`)

---@class YayRemoveOpts: YayCommonOpts
---@field recursive boolean? Add `s` to removal flags (i.e. `-Rs`)
---@field nosave boolean? Add `n` to removal flags (i.e. `-Rn`)
---@field cascade boolean? Add `c` to removal flags (i.e. `-Rc`)

---@class Yay
---@field bin string
---@field sudo_bin string
---@field sync fun(opts: YaySyncOpts|nil): ward.Cmd
---@field upgrade fun(opts: YaySyncOpts|nil): ward.Cmd
---@field install fun(pkgs: string|string[], opts: YayCommonOpts|nil): ward.Cmd
---@field remove fun(pkgs: string|string[], opts: YayRemoveOpts|nil): ward.Cmd
---@field search fun(pattern: string, opts: YayCommonOpts|nil): ward.Cmd
---@field info fun(pkg: string, opts: YayCommonOpts|nil): ward.Cmd
local Yay = {
	bin = "yay",
	sudo_bin = "sudo",
}

--- @param pkgs string|string[]
--- @return string[]
local function normalize_pkgs(pkgs)
	return args_util.normalize_string_or_array(pkgs, "pkg")
end

---@param args string[]
---@param opts YayCommonOpts|nil
local function apply_common(args, opts)
	opts = opts or {}
	args_util.parser(args, opts):flag("needed", "--needed"):flag("noconfirm", "--noconfirm"):extra()
end

---@param argv string[]
---@param opts YayCommonOpts|nil
---@return ward.Cmd
local function build(argv, opts)
	ensure.bin(Yay.bin, { label = "yay binary" })
	opts = opts or {}
	local args = {}
	if opts.sudo then
		ensure.bin(Yay.sudo_bin, { label = "sudo binary" })
		table.insert(args, Yay.sudo_bin)
	end
	table.insert(args, Yay.bin)
	for _, v in ipairs(argv) do
		table.insert(args, tostring(v))
	end
	return _cmd.cmd(table.unpack(args))
end

---Synchronize package databases: `yay -Sy` (or `-Syy` with refresh=true)
---@param opts YaySyncOpts|nil
---@return ward.Cmd
function Yay.sync(opts)
	opts = opts or {}
	local op = opts.refresh and "-Syy" or "-Sy"
	local argv = { op }
	apply_common(argv, opts)
	return build(argv, opts)
end

---System upgrade: `yay -Syu` (or `-Syyu` with refresh=true)
---@param opts YaySyncOpts|nil
---@return ward.Cmd
function Yay.upgrade(opts)
	opts = opts or {}
	local op = opts.refresh and "-Syyu" or "-Syu"
	local argv = { op }
	apply_common(argv, opts)
	return build(argv, opts)
end

---Install packages: `yay -S <pkgs...>`
---@param pkgs string|string[]
---@param opts YayCommonOpts|nil
---@return ward.Cmd
function Yay.install(pkgs, opts)
	opts = opts or {}
	local argv = { "-S" }
	apply_common(argv, opts)
	for _, p in ipairs(normalize_pkgs(pkgs)) do
		table.insert(argv, p)
	end
	return build(argv, opts)
end

---Remove packages: `yay -R[flags] <pkgs...>`
---@param pkgs string|string[]
---@param opts YayRemoveOpts|nil
---@return ward.Cmd
function Yay.remove(pkgs, opts)
	opts = opts or {}
	local flags = ""
	if opts.nosave then
		flags = flags .. "n"
	end
	if opts.recursive then
		flags = flags .. "s"
	end
	if opts.cascade then
		flags = flags .. "c"
	end
	local argv = { "-R" .. flags }
	apply_common(argv, opts)
	for _, p in ipairs(normalize_pkgs(pkgs)) do
		table.insert(argv, p)
	end
	return build(argv, opts)
end

---Search sync db: `yay -Ss <pattern>`
---@param pattern string
---@param opts YayCommonOpts|nil
---@return ward.Cmd
function Yay.search(pattern, opts)
	opts = opts or {}
	validate.non_empty_string(pattern, "pattern")
	local argv = { "-Ss" }
	apply_common(argv, opts)
	table.insert(argv, pattern)
	return build(argv, opts)
end

---Package info for installed package: `yay -Qi <pkg>`
---@param pkg string
---@param opts YayCommonOpts|nil
---@return ward.Cmd
function Yay.info(pkg, opts)
	opts = opts or {}
	validate.non_empty_string(pkg, "pkg")
	local argv = { "-Qi" }
	apply_common(argv, opts)
	table.insert(argv, pkg)
	return build(argv, opts)
end

return {
	Yay = Yay,
}
