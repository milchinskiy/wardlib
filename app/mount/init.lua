---@diagnostic disable: undefined-doc-name

-- mount/umount wrapper module
--
-- Thin wrappers around util-linux `mount` and `umount` that construct CLI
-- invocations and return `ward.process.cmd(...)` objects.
--
-- This module models a small set of commonly used options. Anything not modeled
-- can be passed through with `opts.extra`.

local _cmd = require("ward.process")
local validate = require("util.validate")
local args_util = require("util.args")

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

local function validate_token(value, label)
	assert(type(value) == "string" and #value > 0, label .. " must be a non-empty string")
	assert(value:sub(1, 1) ~= "-", label .. " must not start with '-': " .. tostring(value))
	assert(not value:find("%s"), label .. " must not contain whitespace: " .. tostring(value))
end

local function join_options(value)
	if value == nil then
		return nil
	end
	if type(value) == "string" then
		assert(#value > 0, "options must be a non-empty string")
		return value
	end
	assert(type(value) == "table", "options must be a string or string[]")
	local out = {}
	for _, v in ipairs(value) do
		out[#out + 1] = tostring(v)
	end
	return table.concat(out, ",")
end

local function append_extra(args, extra)
	args_util.append_extra(args, extra)
end

---`mount [opts] [source] [target]`
---
---If both `source` and `target` are nil, this corresponds to plain `mount`.
---@param source string|nil
---@param target string|nil
---@param opts MountOpts|nil
---@return ward.Cmd
function Mount.mount(source, target, opts)
	validate.bin(Mount.mount_bin, "mount binary")
	opts = opts or {}

	local args = { Mount.mount_bin }

	if opts.verbose then
		table.insert(args, "-v")
	end
	if opts.fake then
		table.insert(args, "-f")
	end
	if opts.bind then
		table.insert(args, "--bind")
	end
	if opts.rbind then
		table.insert(args, "--rbind")
	end
	if opts.move then
		table.insert(args, "--move")
	end

	if opts.fstype ~= nil then
		validate_token(opts.fstype, "fstype")
		table.insert(args, "-t")
		table.insert(args, opts.fstype)
	end

	local o = join_options(opts.options)
	if opts.readonly then
		if o == nil or #o == 0 then
			o = "ro"
		else
			o = o .. ",ro"
		end
	end
	if o ~= nil then
		table.insert(args, "-o")
		table.insert(args, o)
	end

	append_extra(args, opts.extra)

	if source ~= nil then
		validate_token(source, "source")
		table.insert(args, source)
	end
	if target ~= nil then
		validate_token(target, "target")
		table.insert(args, target)
	end

	return _cmd.cmd(table.unpack(args))
end

---`umount [opts] <target>`
---@param target string
---@param opts UmountOpts|nil
---@return ward.Cmd
function Mount.umount(target, opts)
	validate.bin(Mount.umount_bin, "umount binary")
	validate_token(target, "target")
	opts = opts or {}

	local args = { Mount.umount_bin }
	if opts.lazy then
		table.insert(args, "-l")
	end
	if opts.force then
		table.insert(args, "-f")
	end
	if opts.recursive then
		table.insert(args, "-R")
	end
	if opts.verbose then
		table.insert(args, "-v")
	end

	append_extra(args, opts.extra)
	table.insert(args, target)

	return _cmd.cmd(table.unpack(args))
end

return {
	Mount = Mount,
}
