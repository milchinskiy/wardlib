--- wardlib.util.args
---
--- Common argv-building helpers for wardlib wrappers.

local validate = require("util.validate")
local tbl = require("util.table")

local M = {}

---Return true when `t` is a dense array table (1..n with no extra keys).
---This is stricter than `util.table.is_array` and matches patterns used in
---some wrappers.
---@param t any
---@return boolean
function M.is_array_strict(t)
	if type(t) ~= "table" then
		return false
	end
	local n = #t
	for k, _ in pairs(t) do
		if type(k) ~= "number" then
			return false
		end
		if k < 1 or k > n or k % 1 ~= 0 then
			return false
		end
	end
	return true
end

---Stable-sort keys of a map-like table.
---@param m table
---@return string[]
function M.sorted_keys(m)
	assert(type(m) == "table", "sorted_keys expects a table")
	local keys = {}
	for k, _ in pairs(m) do
		keys[#keys + 1] = k
	end
	table.sort(keys, function(a, b)
		return tostring(a) < tostring(b)
	end)
	return keys
end

---Validate a token intended to be used as a *positional* (or subcommand)
---argument rather than a flag.
---
---Rules observed across wrappers:
---* non-empty string
---* must not start with '-'
---* must not contain whitespace
---@param value any
---@param label string
---@return string
function M.token(value, label)
	assert(type(value) == "string" and #value > 0, label .. " must be a non-empty string")
	assert(value:sub(1, 1) ~= "-", label .. " must not start with '-': " .. tostring(value))
	assert(not value:find("%s"), label .. " must not contain whitespace: " .. tostring(value))
	return value
end

---Join an option value that can be string or string[] into a comma-separated
---string (used by e.g. mount -o).
---@param v string|string[]|nil
---@param label string
---@return string|nil
function M.join_csv(v, label)
	if v == nil then
		return nil
	end
	if type(v) == "string" then
		validate.non_empty_string(v, label)
		return v
	end
	assert(type(v) == "table", label .. " must be a string or string[]")
	assert(#v > 0, label .. " must be non-empty")
	local out = {}
	for _, x in ipairs(v) do
		validate.non_empty_string(x, label)
		out[#out + 1] = tostring(x)
	end
	return table.concat(out, ",")
end

---Normalize a value that can be either:
---* array of strings (e.g. {"a=b", "c=d"})
---* map of key->value (e.g. { a = 1, b = "x" })
---into a deterministic array of strings.
---
---This matches patterns in wrappers such as awk (vars/assigns) where callers
---can choose either representation.
---@param v table|nil
---@param label string
---@return string[]
function M.kv_list(v, label)
	if v == nil then
		return {}
	end
	assert(type(v) == "table", label .. " must be a table")
	-- Array form: assume each entry is already a "k=v" string.
	if M.is_array_strict(v) then
		local out = {}
		for _, kv in ipairs(v) do
			validate.non_empty_string(kv, label)
			out[#out + 1] = tostring(kv)
		end
		return out
	end
	-- Map form: produce stable-sorted "k=v" strings.
	local out = {}
	for _, k in ipairs(M.sorted_keys(v)) do
		validate.non_empty_string(k, label .. " key")
		local vv = v[k]
		assert(vv ~= nil, label .. "['" .. k .. "'] is nil")
		out[#out + 1] = k .. "=" .. tostring(vv)
	end
	return out
end

-- OptParser
---@class wardlib.util.args.OptParser
---@field args string[]
---@field opts table
local OptParser = {}
OptParser.__index = OptParser

---@param args string[]
---@param opts table|nil
---@return wardlib.util.args.OptParser
function M.parser(args, opts)
	assert(type(args) == "table", "parser expects args array")
	local p = {
		args = args,
		opts = opts or {},
	}
	assert(type(p.opts) == "table", "opts must be a table")
	return setmetatable(p, OptParser)
end

---@param key string
---@param flag string
---@return wardlib.util.args.OptParser
function OptParser:flag(key, flag)
	if self.opts[key] then
		self.args[#self.args + 1] = flag
	end
	return self
end

---@class wardlib.util.args.ValueCfg
---@field label string? Label used in error messages
---@field tostring boolean? Convert the value to string (default true)
---@field validate fun(v:any, label:string)? Custom validator
---@field mode 'pair'|'equals'? pair => `--flag <val>`, equals => `--flag=<val>`

---@param key string
---@param flag string
---@param cfg wardlib.util.args.ValueCfg|nil
---@return wardlib.util.args.OptParser
function OptParser:value(key, flag, cfg)
	local v = self.opts[key]
	if v == nil then
		return self
	end
	cfg = cfg or {}
	local label = cfg.label or key
	if cfg.validate ~= nil then
		cfg.validate(v, label)
	end
	local sv = v
	if cfg.tostring ~= false then
		sv = tostring(v)
	end
	local mode = cfg.mode or "pair"
	if mode == "equals" then
		self.args[#self.args + 1] = flag .. "=" .. tostring(sv)
	else
		self.args[#self.args + 1] = flag
		self.args[#self.args + 1] = tostring(sv)
	end
	return self
end

---@param key string
---@param flag string
---@param label string|nil
---@return wardlib.util.args.OptParser
function OptParser:value_string(key, flag, label)
	return self:value(key, flag, { label = label or key, validate = validate.non_empty_string })
end

---@param key string
---@param flag string
---@param label string|nil
---@return wardlib.util.args.OptParser
function OptParser:value_token(key, flag, label)
	return self:value(key, flag, { label = label or key, validate = validate.not_flag })
end

---@class wardlib.util.args.NumberCfg: wardlib.util.args.ValueCfg
---@field min number? Minimum allowed value
---@field non_negative boolean? If true, require >= 0
---@field integer boolean? If true, require integer

---@param key string
---@param flag string
---@param cfg wardlib.util.args.NumberCfg|nil
---@return wardlib.util.args.OptParser
function OptParser:value_number(key, flag, cfg)
	local v = self.opts[key]
	if v == nil then
		return self
	end
	cfg = cfg or {}
	local label = cfg.label or key
	if cfg.integer then
		validate.integer(v, label)
	elseif cfg.non_negative then
		validate.number_non_negative(v, label)
	else
		validate.number_min(v, label)
	end
	if cfg.min ~= nil then
		validate.number_min(v, label, cfg.min)
	end
	return self:value(key, flag, { label = label, mode = cfg.mode })
end

---@class wardlib.util.args.RepeatCfg
---@field label string?
---@field validate fun(v:any, label:string)?
---@field tostring boolean?
---@field mode 'pair'|'equals'?

---Add a repeatable flag/value pair where the value can be string or string[].
---@param key string
---@param flag string
---@param cfg wardlib.util.args.RepeatCfg|nil
---@return wardlib.util.args.OptParser
function OptParser:repeatable(key, flag, cfg)
	local v = self.opts[key]
	if v == nil then
		return self
	end
	cfg = cfg or {}
	local label = cfg.label or key
	local values = M.normalize_string_or_array(v, label)
	for _, s in ipairs(values) do
		if cfg.validate ~= nil then
			cfg.validate(s, label)
		end
		local mode = cfg.mode or "pair"
		if mode == "equals" then
			self.args[#self.args + 1] = flag .. "=" .. tostring(s)
		else
			self.args[#self.args + 1] = flag
			self.args[#self.args + 1] = tostring(s)
		end
	end
	return self
end

---Add a repeatable flag/value pair from a map, in stable key order.
---Adds: `<flag> <key> <value>` repeated.
---@param key string
---@param flag string
---@param cfg { label?: string, key_label?: string, value_label?: string, key_validate?: fun(v:any,label:string), value_validate?: fun(v:any,label:string), tostring?: boolean }|nil
---@return wardlib.util.args.OptParser
function OptParser:repeatable_map(key, flag, cfg)
	local m = self.opts[key]
	if m == nil then
		return self
	end
	assert(type(m) == "table", (cfg and cfg.label or key) .. " must be a table")
	cfg = cfg or {}
	local key_label = cfg.key_label or (key .. " key")
	local value_label = cfg.value_label or (key .. " value")
	for _, k in ipairs(M.sorted_keys(m)) do
		local vv = m[k]
		assert(vv ~= nil, key .. "['" .. k .. "'] is nil")
		if cfg.key_validate ~= nil then
			cfg.key_validate(k, key_label)
		end
		if cfg.value_validate ~= nil then
			cfg.value_validate(vv, value_label)
		end
		self.args[#self.args + 1] = flag
		self.args[#self.args + 1] = tostring(k)
		self.args[#self.args + 1] = tostring(vv)
	end
	return self
end

---Handle a boolean OR value option.
---
---If opts[key] is:
---* true  => add `<flag>`
---* string/number => add `<flag> <value>` or `<flag>=<value>` (cfg.mode)
---@param key string
---@param flag string
---@param cfg wardlib.util.args.ValueCfg|nil
---@return wardlib.util.args.OptParser
function OptParser:bool_or_value(key, flag, cfg)
	local v = self.opts[key]
	if v == nil then
		return self
	end
	if v == true then
		self.args[#self.args + 1] = flag
		return self
	end
	assert(v ~= false, key .. " must be true or a value")
	return self:value(key, flag, cfg)
end

---Handle a boolean OR value option where the value is encoded as `--flag=<val>`.
---This matches awk-style optional-value long flags.
---@param key string
---@param flag string
---@param cfg { label?: string, validate?: fun(v:any,label:string) }|nil
---@return wardlib.util.args.OptParser
function OptParser:bool_or_equals(key, flag, cfg)
	local v = self.opts[key]
	if v == nil then
		return self
	end
	if v == true then
		self.args[#self.args + 1] = flag
		return self
	end
	assert(v ~= false, key .. " must be true or a value")
	cfg = cfg or {}
	local label = cfg.label or key
	if cfg.validate ~= nil then
		cfg.validate(v, label)
	end
	self.args[#self.args + 1] = flag .. "=" .. tostring(v)
	return self
end

---Handle a count option where opts[key] is boolean|number.
---
---If true => repeat `flag` `true_count` times (default 1).
---If number => repeat `flag` N times (N >= min, default 1).
---@param key string
---@param flag string
---@param cfg { label?: string, true_count?: integer, min?: integer }|nil
---@return wardlib.util.args.OptParser
function OptParser:count(key, flag, cfg)
	local v = self.opts[key]
	if v == nil then
		return self
	end
	cfg = cfg or {}
	local label = cfg.label or key
	local min = cfg.min or 1
	local n
	if v == true then
		n = cfg.true_count or 1
	elseif type(v) == "number" then
		validate.integer_min(v, label, min)
		n = v
	else
		error(label .. " must be boolean or number")
	end
	for _ = 1, n do
		self.args[#self.args + 1] = flag
	end
	return self
end

---Assert that at most one of `keys` is set (truthy) in opts.
---@param keys string[]
---@param label string|nil
---@return wardlib.util.args.OptParser
function OptParser:mutually_exclusive(keys, label)
	assert(type(keys) == "table" and #keys > 0, "keys must be a non-empty array")
	local set = {}
	for _, k in ipairs(keys) do
		if self.opts[k] then
			set[#set + 1] = k
		end
	end
	if #set > 1 then
		error((label or "options") .. " are mutually exclusive: " .. table.concat(set, ", "))
	end
	return self
end

---Convenience: append opts.extra (or another key) using `append_extra`.
---@param key string|nil
---@return wardlib.util.args.OptParser
function OptParser:extra(key)
	M.append_extra(self.args, self.opts[key or "extra"])
	return self
end

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
