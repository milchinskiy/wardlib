---@diagnostic disable: undefined-doc-name

-- dconf wrapper module
--
-- This module is intentionally thin: it constructs `dconf` CLI invocations and
-- returns `ward.process.cmd(...)` objects so callers can decide how/when to run
-- them and how to capture output.

local _cmd = require("ward.process")
local ensure = require("wardlib.tools.ensure")
local args_util = require("wardlib.util.args")

---@class wardlib.DconfRaw
---@field __raw true
---@field value string

---@class Dconf
---@field bin string Executable name or path
---@field raw fun(value: string): wardlib.DconfRaw
---@field encode fun(value: any): string
---@field read fun(key: string): ward.Cmd
---@field write fun(key: string, value: any): ward.Cmd
---@field reset fun(key_or_dir: string, opts: {force: boolean?}?): ward.Cmd
---@field list fun(dir: string): ward.Cmd
---@field dump fun(dir: string): ward.Cmd
---@field load fun(dir: string, data: string|nil): ward.Cmd
local Dconf = {
	bin = "dconf",
}

---Validate dconf key path
---@param key string
local function validate_key(key)
	assert(type(key) == "string" and #key > 0, "key must be a non-empty string")
	assert(key:sub(1, 1) == "/", "key must start with '/': " .. tostring(key))
	assert(not key:find("%s"), "key must not contain whitespace: " .. tostring(key))
	-- A key must not end with '/'. Directories do.
	assert(key:sub(-1) ~= "/", "key must not end with '/': " .. tostring(key))
end

---Validate dconf directory path (used by list/dump/load and reset -f)
---@param dir string
local function validate_dir(dir)
	assert(type(dir) == "string" and #dir > 0, "dir must be a non-empty string")
	assert(dir:sub(1, 1) == "/", "dir must start with '/': " .. tostring(dir))
	assert(not dir:find("%s"), "dir must not contain whitespace: " .. tostring(dir))
	-- dconf expects trailing slash for directories in list/dump/load/reset -f.
	assert(dir:sub(-1) == "/", "dir must end with '/': " .. tostring(dir))
end

---Create a raw GVariant literal (no encoding/quoting is applied)
---@param value string
---@return wardlib.DconfRaw
function Dconf.raw(value)
	assert(type(value) == "string", "raw value must be a string")
	return { __raw = true, value = value }
end

---Encode common Lua primitives into dconf/GVariant literals.
---
---Supported:
---  * string  -> quoted string (single quotes, with basic escaping)
---  * boolean -> true/false
---  * number  -> number literal
---  * raw(..) -> passed through as-is
---
---Anything else should be supplied as `raw("<gvariant>")`.
---@param value any
---@return string
function Dconf.encode(value)
	if type(value) == "table" and value.__raw == true then
		return tostring(value.value)
	end

	local t = type(value)
	if t == "string" then
		-- dconf CLI expects GVariant strings wrapped in single quotes.
		-- Inside that string, backslash and single quote should be escaped.
		local s = value:gsub("\\", "\\\\"):gsub("'", "\\'")
		return "'" .. s .. "'"
	elseif t == "boolean" then
		return value and "true" or "false"
	elseif t == "number" then
		-- avoid locale-specific formatting
		return tostring(value)
	elseif value == nil then
		error("cannot encode nil; use Dconf.raw(...) or pass a concrete value")
	end

	error("unsupported value type for dconf encoding: " .. t .. " (use Dconf.raw(...))")
end

---Read a key
---@param key string
---@return ward.Cmd
function Dconf.read(key)
	ensure.bin(Dconf.bin, { label = "dconf binary" })
	validate_key(key)
	return _cmd.cmd(Dconf.bin, "read", key)
end

---Write a key
---@param key string
---@param value any
---@return ward.Cmd
function Dconf.write(key, value)
	ensure.bin(Dconf.bin, { label = "dconf binary" })
	validate_key(key)
	local encoded = Dconf.encode(value)
	return _cmd.cmd(Dconf.bin, "write", key, encoded)
end

---Reset a key or directory
---@param key_or_dir string
---@param opts {force: boolean?}?
---@return ward.Cmd
function Dconf.reset(key_or_dir, opts)
	ensure.bin(Dconf.bin, { label = "dconf binary" })
	opts = opts or {}

	assert(type(key_or_dir) == "string" and #key_or_dir > 0, "path must be a non-empty string")
	assert(key_or_dir:sub(1, 1) == "/", "path must start with '/': " .. tostring(key_or_dir))

	if opts.force then
		validate_dir(key_or_dir)
		local args = { Dconf.bin, "reset" }
		args_util.parser(args, { force = true }):flag("force", "-f")
		args[#args + 1] = key_or_dir
		return _cmd.cmd(table.unpack(args))
	end

	validate_key(key_or_dir)
	local args = { Dconf.bin, "reset", key_or_dir }
	return _cmd.cmd(table.unpack(args))
end

---List keys and subdirs under a directory
---@param dir string
---@return ward.Cmd
function Dconf.list(dir)
	ensure.bin(Dconf.bin, { label = "dconf binary" })
	validate_dir(dir)
	return _cmd.cmd(Dconf.bin, "list", dir)
end

---Dump subtree under a directory (prints keyfile format to stdout)
---@param dir string
---@return ward.Cmd
function Dconf.dump(dir)
	ensure.bin(Dconf.bin, { label = "dconf binary" })
	validate_dir(dir)
	return _cmd.cmd(Dconf.bin, "dump", dir)
end

---Load subtree under a directory.
---
---If `data` is provided, this function attempts to attach it as stdin on the
---returned command if the underlying Cmd supports `:stdin(...)`. If it doesn't,
---the data is stored on the command as `stdin_data` for consumers that support
---out-of-band stdin handling.
---@param dir string
---@param data string|nil
---@return ward.Cmd
function Dconf.load(dir, data)
	ensure.bin(Dconf.bin, { label = "dconf binary" })
	validate_dir(dir)

	local c = _cmd.cmd(Dconf.bin, "load", dir)
	if data ~= nil then
		assert(type(data) == "string", "data must be a string")
		if type(c.stdin) == "function" then
			c:stdin(data)
		else
			c.stdin_data = data
		end
	end
	return c
end

return {
	Dconf = Dconf,
}
