---@diagnostic disable: undefined-doc-name

-- chroot wrapper module
--
-- Thin wrappers around `chroot` that construct CLI invocations and return
-- `ward.process.cmd(...)` objects.
--
-- This module models the common GNU coreutils chroot flags:
--   * --userspec=USER:GROUP
--   * --groups=G1,G2,...
--   * --skip-chdir
--
-- Everything else can be passed through via `opts.extra`.

local _cmd = require("ward.process")
local args_util = require("wardlib.util.args")
local ensure = require("wardlib.tools.ensure")

---@class ChrootOpts
---@field userspec string? Add `--userspec=<user>:<group>`
---@field groups string|string[]? Add `--groups=<g1>,<g2>`
---@field skip_chdir boolean? Add `--skip-chdir`
---@field extra string[]? Extra args appended before positional args

---@class Chroot
---@field bin string Executable name or path to `chroot`
---@field run fun(root: string, argv: string[]|nil, opts: ChrootOpts|nil): ward.Cmd
local Chroot = {
	bin = "chroot",
}

local function validate_token(value, label)
	assert(type(value) == "string" and #value > 0, label .. " must be a non-empty string")
	assert(value:sub(1, 1) ~= "-", label .. " must not start with '-': " .. tostring(value))
	assert(not value:find("%s"), label .. " must not contain whitespace: " .. tostring(value))
end

local function join_groups(value)
	if value == nil then return nil end
	if type(value) == "string" then
		assert(#value > 0, "groups must be a non-empty string")
		return value
	end
	assert(type(value) == "table", "groups must be a string or string[]")
	local out = {}
	for _, v in ipairs(value) do
		out[#out + 1] = tostring(v)
	end
	return table.concat(out, ",")
end

local function append_extra(args, extra) args_util.append_extra(args, extra) end

---`chroot [opts] <newroot> [command [args...]]`
---@param root string
---@param argv string[]|nil
---@param opts ChrootOpts|nil
---@return ward.Cmd
function Chroot.run(root, argv, opts)
	ensure.bin(Chroot.bin, { label = "chroot binary" })
	validate_token(root, "root")
	opts = opts or {}

	local args = { Chroot.bin }

	if opts.userspec ~= nil then
		validate_token(opts.userspec, "userspec")
		table.insert(args, "--userspec=" .. opts.userspec)
	end

	local g = join_groups(opts.groups)
	if g ~= nil then table.insert(args, "--groups=" .. g) end

	if opts.skip_chdir then table.insert(args, "--skip-chdir") end

	append_extra(args, opts.extra)
	table.insert(args, root)

	if argv ~= nil then
		assert(type(argv) == "table", "argv must be an array")
		for _, v in ipairs(argv) do
			table.insert(args, tostring(v))
		end
	end

	return _cmd.cmd(table.unpack(args))
end

return {
	Chroot = Chroot,
}
