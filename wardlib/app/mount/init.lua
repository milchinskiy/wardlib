---@diagnostic disable: undefined-doc-name

-- mount/umount wrapper module
--
-- Thin wrappers around util-linux `mount` and `umount` that construct CLI
-- invocations and return `ward.process.cmd(...)` objects.
--
-- This module models a small set of commonly used options. Anything not modeled
-- can be passed through with `opts.extra`.

local _cmd = require("ward.process")
local ensure = require("wardlib.tools.ensure")
local args_util = require("wardlib.util.args")

---@class MountCommonOpts
---@field extra string[]? Extra args appended before positional args

---@class MountOpts: MountCommonOpts
---@field fstype string? Add `-t <fstype>`
---@field options string|string[]? Add `-o <opts>` (string or list joined by commas)
---@field readonly boolean? Add `ro` to `-o`
---@field bind boolean? Add `--bind`
---@field rbind boolean? Add `--rbind`
---@field move boolean? Add `--move`
---@field verbose boolean? Add `-v`
---@field fake boolean? Add `-f`

---@class UmountOpts: MountCommonOpts
---@field lazy boolean? Add `-l`
---@field force boolean? Add `-f`
---@field recursive boolean? Add `-R`
---@field verbose boolean? Add `-v`

---@class Mount
---@field mount_bin string Executable name or path to `mount`
---@field umount_bin string Executable name or path to `umount`
---@field mount fun(source: string|nil, target: string|nil, opts: MountOpts|nil): ward.Cmd
---@field umount fun(target: string, opts: UmountOpts|nil): ward.Cmd
local Mount = {
	mount_bin = "mount",
	umount_bin = "umount",
}

---`mount [opts] [source] [target]`
---
---If both `source` and `target` are nil, this corresponds to plain `mount`.
---@param source string|nil
---@param target string|nil
---@param opts MountOpts|nil
---@return ward.Cmd
function Mount.mount(source, target, opts)
	ensure.bin(Mount.mount_bin, { label = "mount binary" })
	opts = opts or {}

	local args = { Mount.mount_bin }
	local p = args_util.parser(args, opts)
	p:flag("verbose", "-v"):flag("fake", "-f"):flag("bind", "--bind"):flag("rbind", "--rbind"):flag("move", "--move")

	if opts.fstype ~= nil then
		args[#args + 1] = "-t"
		args[#args + 1] = args_util.token(opts.fstype, "fstype")
	end

	local o = args_util.join_csv(opts.options, "options")
	if opts.readonly then
		if o == nil or #o == 0 then
			o = "ro"
		else
			o = o .. ",ro"
		end
	end
	if o ~= nil then
		args[#args + 1] = "-o"
		args[#args + 1] = o
	end

	p:extra()

	if source ~= nil then
		args[#args + 1] = args_util.token(source, "source")
	end
	if target ~= nil then
		args[#args + 1] = args_util.token(target, "target")
	end

	return _cmd.cmd(table.unpack(args))
end

---`umount [opts] <target>`
---@param target string
---@param opts UmountOpts|nil
---@return ward.Cmd
function Mount.umount(target, opts)
	ensure.bin(Mount.umount_bin, { label = "umount binary" })
	args_util.token(target, "target")
	opts = opts or {}

	local args = { Mount.umount_bin }
	args_util
		.parser(args, opts)
		:flag("lazy", "-l")
		:flag("force", "-f")
		:flag("recursive", "-R")
		:flag("verbose", "-v")
		:extra()

	args[#args + 1] = target
	return _cmd.cmd(table.unpack(args))
end

return {
	Mount = Mount,
}
