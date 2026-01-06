--- wardlib.util.args
---
--- Common argv-building helpers for wardlib wrappers.
---
--- Intentionally small: it exists only to remove repetitive boilerplate in
--- wrappers (mostly around `extra` and repeatable flags).

local validate = require("util.validate")
local tbl = require("util.table")

local M = {}

--- Append `extra` argv entries.
--- @param args string[]
--- @param extra string[]|nil
function M.append_extra(args, extra)
	if extra == nil then
		return
	end
	assert(type(extra) == "table", "extra must be an array")
	for _, v in ipairs(extra) do
		args[#args + 1] = tostring(v)
	end
end

--- Normalize a value that can be either `string` or `string[]` into an array.
--- @param v string|string[]
--- @param label string
--- @return string[]
function M.normalize_string_or_array(v, label)
	if type(v) == "string" then
		validate.non_empty_string(v, label)
		return { v }
	end
	assert(type(v) == "table", label .. " must be a string or string[]")
	assert(#v > 0, label .. " must be non-empty")
	local out = {}
	for _, s in ipairs(v) do
		validate.non_empty_string(s, label)
		out[#out + 1] = tostring(s)
	end
	return out
end

--- Add a repeatable flag/value pair where the value can be `string` or `string[]`.
--- @param args string[]
--- @param v string|string[]
--- @param flag string
--- @param label string
function M.add_repeatable(args, v, flag, label)
	local values = M.normalize_string_or_array(v, label)
	for _, s in ipairs(values) do
		args[#args + 1] = flag
		args[#args + 1] = s
	end
end

--- Clone an `opts` table and (optionally) clone some array fields.
--- This exists purely for the "do not mutate caller opts" rule.
--- @param opts table|nil
--- @param array_fields string[]|nil
--- @return table
function M.clone_opts(opts, array_fields)
	local o = tbl.shallow_copy(opts)
	if array_fields ~= nil then
		for _, k in ipairs(array_fields) do
			o[k] = tbl.clone_array_value(o[k])
		end
	end
	return o
end

return M
