---@diagnostic disable: undefined-doc-name

-- gsettings wrapper module
--
-- Thin wrappers around `gsettings` that construct CLI invocations and return
-- `ward.process.cmd(...)` objects.

local _cmd = require("ward.process")
local args_util = require("wardlib.util.args")
local ensure = require("wardlib.tools.ensure")

---@class Gsettings
---@field bin string
---@field get fun(schema: string, key: string): ward.Cmd
---@field set fun(schema: string, key: string, value: string): ward.Cmd
---@field reset fun(schema: string, key: string): ward.Cmd
---@field list_keys fun(schema: string): ward.Cmd
---@field list_schemas fun(): ward.Cmd
---@field list_recursively fun(schema_or_path: string|nil): ward.Cmd
local Gsettings = {
	bin = "gsettings",
}

---@param args string[]
---@return ward.Cmd
local function cmd(args)
	ensure.bin(Gsettings.bin, { label = "gsettings binary" })
	local argv = { Gsettings.bin }
	for _, v in ipairs(args) do
		table.insert(argv, v)
	end
	return _cmd.cmd(table.unpack(argv))
end

function Gsettings.get(schema, key)
	args_util.token(schema, "schema")
	args_util.token(key, "key")
	return cmd({ "get", schema, key })
end

function Gsettings.set(schema, key, value)
	args_util.token(schema, "schema")
	args_util.token(key, "key")
	assert(type(value) == "string" and #value > 0, "value must be a non-empty string")
	return cmd({ "set", schema, key, value })
end

function Gsettings.reset(schema, key)
	args_util.token(schema, "schema")
	args_util.token(key, "key")
	return cmd({ "reset", schema, key })
end

function Gsettings.list_keys(schema)
	args_util.token(schema, "schema")
	return cmd({ "list-keys", schema })
end

function Gsettings.list_schemas() return cmd({ "list-schemas" }) end

function Gsettings.list_recursively(schema_or_path)
	if schema_or_path ~= nil then
		args_util.token(schema_or_path, "schema_or_path")
		return cmd({ "list-recursively", schema_or_path })
	end
	return cmd({ "list-recursively" })
end

return {
	Gsettings = Gsettings,
}
