--- wardlib.util.table
---
--- Small table helpers used internally by wardlib.
---
--- Notes:
--- * We intentionally keep this tiny and dependency-free.
--- * This does NOT try to replace Ward builtins; it only centralizes repeated
---   wardlib-only patterns (copying opts tables, cloning argv arrays, etc.).

local M = {}

--- Return true when `t` is an array-like table (1..n dense).
--- @param t any
--- @return boolean
function M.is_array(t) return type(t) == "table" and t[1] ~= nil end

--- Clone an array-like table.
--- @param t table
--- @return table
function M.clone_array(t)
	assert(type(t) == "table", "clone_array expects a table")
	local out = {}
	for i = 1, #t do
		out[i] = t[i]
	end
	return out
end

--- Shallow-copy a table.
---
--- * Copies key/value pairs.
--- * Does not deep-copy nested tables.
--- @param t table|nil
--- @return table
function M.shallow_copy(t)
	if t == nil then return {} end
	assert(type(t) == "table", "shallow_copy expects a table")
	local out = {}
	for k, v in pairs(t) do
		out[k] = v
	end
	return out
end

--- Clone an array value if it is an array table; otherwise return as-is.
--- Useful to avoid mutating caller-provided arrays inside opts.
--- @param v any
--- @return any
function M.clone_array_value(v)
	if type(v) == "table" and M.is_array(v) then return M.clone_array(v) end
	return v
end

return M
