---@diagnostic disable: undefined-doc-name

-- chattr wrapper module
--
-- Thin wrappers around `chattr` that construct CLI invocations and return
-- `ward.process.cmd(...)` objects.
--
-- This module intentionally does not parse output.
--
-- Notes:
-- - `chattr` is Linux/EXT-focused; feature sets differ across filesystems.

local _cmd = require("ward.process")
local validate = require("wardlib.util.validate")
local ensure = require("wardlib.tools.ensure")
local args_util = require("wardlib.util.args")

---@class ChattrOpts
---@field recursive boolean? `-R`
---@field verbose boolean? `-V`
---@field force boolean? `-f`
---@field version integer? `-v <version>`
---@field extra string[]? Extra args appended after modeled options

---@class Chattr
---@field bin string Executable name or path to `chattr`
---@field set fun(paths: string|string[], mode: string, opts: ChattrOpts|nil): ward.Cmd
---@field raw fun(argv: string|string[], opts: ChattrOpts|nil): ward.Cmd
local Chattr = {
	bin = "chattr",
}

---@param args string[]
---@param opts ChattrOpts|nil
local function apply_opts(args, opts)
	opts = opts or {}
	args_util
		.parser(args, opts)
		:flag("recursive", "-R")
		:flag("verbose", "-V")
		:flag("force", "-f")
		:value_number("version", "-v", { label = "version", integer = true })
		:extra("extra")
end

---Set or clear file attributes.
---
---Builds: `chattr <opts...> -- <mode> <paths...>`
---
---`mode` is the attribute mode string (examples: `+i`, `-i`, `=ai`).
---@param paths string|string[]
---@param mode string
---@param opts ChattrOpts|nil
---@return ward.Cmd
function Chattr.set(paths, mode, opts)
	ensure.bin(Chattr.bin, { label = "chattr binary" })
	validate.non_empty_string(mode, "mode")
	local list = args_util.normalize_string_or_array(paths, "paths")
	assert(#list > 0, "paths must not be empty")

	local args = { Chattr.bin }
	apply_opts(args, opts)
	args[#args + 1] = "--"
	args[#args + 1] = mode
	for _, p in ipairs(list) do
		args[#args + 1] = p
	end
	return _cmd.cmd(table.unpack(args))
end

---Low-level escape hatch.
---Builds: `chattr <modeled-opts...> <argv...>`
---@param argv string|string[]
---@param opts ChattrOpts|nil
---@return ward.Cmd
function Chattr.raw(argv, opts)
	ensure.bin(Chattr.bin, { label = "chattr binary" })
	local args = { Chattr.bin }
	apply_opts(args, opts)
	local av = args_util.normalize_string_or_array(argv, "argv")
	for _, s in ipairs(av) do
		args[#args + 1] = s
	end
	return _cmd.cmd(table.unpack(args))
end

return {
	Chattr = Chattr,
}
