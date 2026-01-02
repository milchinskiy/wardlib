---@diagnostic disable: undefined-doc-name

-- gsettings wrapper module
--
-- Thin wrappers around `gsettings` that construct CLI invocations and return
-- `ward.process.cmd(...)` objects.

local _cmd = require("ward.process")
local _env = require("ward.env")
local _fs = require("ward.fs")

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

---@param bin string
local function validate_bin(bin)
	assert(type(bin) == "string" and #bin > 0, "gsettings binary is not set")
	if bin:find("/", 1, true) then
		assert(_fs.is_exists(bin), string.format("gsettings binary does not exist: %s", bin))
		assert(_fs.is_executable(bin), string.format("gsettings binary is not executable: %s", bin))
	else
		assert(_env.is_in_path(bin), string.format("gsettings binary is not in PATH: %s", bin))
	end
end

---@param s any
---@param label string
local function validate_token(s, label)
	assert(type(s) == "string" and #s > 0, label .. " must be a non-empty string")
	assert(not s:find("%s"), label .. " must not contain whitespace: " .. tostring(s))
	assert(s:sub(1, 1) ~= "-", label .. " must not start with '-': " .. tostring(s))
end

---@param args string[]
---@return ward.Cmd
local function cmd(args)
	validate_bin(Gsettings.bin)
	local argv = { Gsettings.bin }
	for _, v in ipairs(args) do
		table.insert(argv, v)
	end
	return _cmd.cmd(table.unpack(argv))
end

function Gsettings.get(schema, key)
	validate_token(schema, "schema")
	validate_token(key, "key")
	return cmd({ "get", schema, key })
end

function Gsettings.set(schema, key, value)
	validate_token(schema, "schema")
	validate_token(key, "key")
	assert(type(value) == "string" and #value > 0, "value must be a non-empty string")
	return cmd({ "set", schema, key, value })
end

function Gsettings.reset(schema, key)
	validate_token(schema, "schema")
	validate_token(key, "key")
	return cmd({ "reset", schema, key })
end

function Gsettings.list_keys(schema)
	validate_token(schema, "schema")
	return cmd({ "list-keys", schema })
end

function Gsettings.list_schemas()
	return cmd({ "list-schemas" })
end

function Gsettings.list_recursively(schema_or_path)
	if schema_or_path ~= nil then
		validate_token(schema_or_path, "schema_or_path")
		return cmd({ "list-recursively", schema_or_path })
	end
	return cmd({ "list-recursively" })
end

return {
	Gsettings = Gsettings,
}
