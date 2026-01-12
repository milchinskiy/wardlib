---@diagnostic disable: undefined-doc-name

-- pacman wrapper module (Arch Linux and derivatives)
--
-- Thin wrappers around `pacman` that construct CLI invocations and return
-- `ward.process.cmd(...)` objects.

local _cmd = require("ward.process")
local validate = require("util.validate")
local ensure = require("tools.ensure")
local args_util = require("util.args")

---@class PacmanCommonOpts
---@field sudo boolean? Prefix with `sudo`
---@field extra string[]? Extra args appended after options
---@field noconfirm boolean? Add `--noconfirm`

---@class PacmanSyncOpts: PacmanCommonOpts
---@field refresh boolean? Add a second `y` (i.e. use `-Syy` / `-Syyu`)

---@class PacmanInstallOpts: PacmanCommonOpts
---@field needed boolean? Add `--needed`

---@class PacmanRemoveOpts: PacmanCommonOpts
---@field recursive boolean? Add `s` to removal flags (i.e. `-Rs`)
---@field nosave boolean? Add `n` to removal flags (i.e. `-Rn`)
---@field cascade boolean? Add `c` to removal flags (i.e. `-Rc`)

---@class Pacman
---@field bin string
---@field sudo_bin string
---@field sync fun(opts: PacmanSyncOpts|nil): ward.Cmd
---@field upgrade fun(opts: PacmanSyncOpts|nil): ward.Cmd
---@field install fun(pkgs: string|string[], opts: PacmanInstallOpts|nil): ward.Cmd
---@field remove fun(pkgs: string|string[], opts: PacmanRemoveOpts|nil): ward.Cmd
---@field search fun(pattern: string, opts: PacmanCommonOpts|nil): ward.Cmd
---@field info fun(pkg: string, opts: PacmanCommonOpts|nil): ward.Cmd
---@field list_installed fun(opts: PacmanCommonOpts|nil): ward.Cmd
local Pacman = {
	bin = "pacman",
	sudo_bin = "sudo",
}

--- @param pkgs string|string[]
--- @return string[]
local function normalize_pkgs(pkgs)
	return args_util.normalize_string_or_array(pkgs, "pkg")
end

---@param args string[]
---@param opts PacmanCommonOpts|nil
local function apply_common(args, opts)
	opts = opts or {}
	args_util.parser(args, opts):flag("noconfirm", "--noconfirm"):extra()
end

---@param op string
---@param argv string[]
---@param opts PacmanCommonOpts|nil
---@return ward.Cmd
local function build(op, argv, opts)
	ensure.bin(Pacman.bin, { label = "pacman binary" })
	opts = opts or {}
	local args = {}
	if opts.sudo then
		ensure.bin(Pacman.sudo_bin, { label = "sudo binary" })
		table.insert(args, Pacman.sudo_bin)
	end
	table.insert(args, Pacman.bin)
	for _, v in ipairs(argv) do
		table.insert(args, tostring(v))
	end
	return _cmd.cmd(table.unpack(args))
end

---Synchronize package databases: `pacman -Sy` (or `-Syy` with refresh=true)
---@param opts PacmanSyncOpts|nil
---@return ward.Cmd
function Pacman.sync(opts)
	opts = opts or {}
	local op = opts.refresh and "-Syy" or "-Sy"
	local argv = { op }
	apply_common(argv, opts)
	return build(op, argv, opts)
end

---System upgrade: `pacman -Syu` (or `-Syyu` with refresh=true)
---@param opts PacmanSyncOpts|nil
---@return ward.Cmd
function Pacman.upgrade(opts)
	opts = opts or {}
	local op = opts.refresh and "-Syyu" or "-Syu"
	local argv = { op }
	apply_common(argv, opts)
	return build(op, argv, opts)
end

---Install packages: `pacman -S <pkgs...>`
---@param pkgs string|string[]
---@param opts PacmanInstallOpts|nil
---@return ward.Cmd
function Pacman.install(pkgs, opts)
	opts = opts or {}
	local op = "-S"
	local argv = { op }
	args_util.parser(argv, opts):flag("needed", "--needed")
	apply_common(argv, opts)
	for _, p in ipairs(normalize_pkgs(pkgs)) do
		table.insert(argv, p)
	end
	return build(op, argv, opts)
end

---Remove packages: `pacman -R[flags] <pkgs...>`
---@param pkgs string|string[]
---@param opts PacmanRemoveOpts|nil
---@return ward.Cmd
function Pacman.remove(pkgs, opts)
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
	local op = "-R" .. flags
	local argv = { op }
	apply_common(argv, opts)
	for _, p in ipairs(normalize_pkgs(pkgs)) do
		table.insert(argv, p)
	end
	return build(op, argv, opts)
end

---Search sync db: `pacman -Ss <pattern>`
---@param pattern string
---@param opts PacmanCommonOpts|nil
---@return ward.Cmd
function Pacman.search(pattern, opts)
	opts = opts or {}
	validate.non_empty_string(pattern, "pattern")
	local op = "-Ss"
	local argv = { op }
	apply_common(argv, opts)
	table.insert(argv, pattern)
	return build(op, argv, opts)
end

---Package info for installed package: `pacman -Qi <pkg>`
---@param pkg string
---@param opts PacmanCommonOpts|nil
---@return ward.Cmd
function Pacman.info(pkg, opts)
	opts = opts or {}
	validate.non_empty_string(pkg, "pkg")
	local op = "-Qi"
	local argv = { op }
	apply_common(argv, opts)
	table.insert(argv, pkg)
	return build(op, argv, opts)
end

---List installed packages: `pacman -Q`
---@param opts PacmanCommonOpts|nil
---@return ward.Cmd
function Pacman.list_installed(opts)
	opts = opts or {}
	local op = "-Q"
	local argv = { op }
	apply_common(argv, opts)
	return build(op, argv, opts)
end

return {
	Pacman = Pacman,
}
