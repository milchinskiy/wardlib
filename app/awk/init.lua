---@diagnostic disable: undefined-doc-name

-- awk wrapper module
--
-- Thin wrappers around `awk` that construct CLI invocations and return
-- `ward.process.cmd(...)` objects.
--
-- This wrapper is intentionally output-agnostic (it does not parse stdout).
-- Consumers decide how to execute returned commands and interpret results.

local _cmd = require("ward.process")
local validate = require("util.validate")
local ensure = require("tools.ensure")

---@class AwkOptKV
---@field [string] any

---@class AwkOpts
---@field field_sep string? `-F <sep>`
---@field vars table? `-v name=value` repeated. Accepts array `{ "k=v" }` or map `{ k = v }`.
---@field assigns table? Post-program assignments `name=value`. Accepts array or map.
---@field includes string[]? gawk: `-i <file>` repeated
---@field extra string[]? Extra args appended before the program / scripts
--
-- Common (mostly gawk) long flags:
---@field posix boolean? `--posix`
---@field traditional boolean? `--traditional`
---@field lint boolean? `--lint`
---@field interval boolean? `--interval`
---@field bignum boolean? `--bignum`
---@field sandbox boolean? `--sandbox`
---@field csv boolean? `--csv`
---@field optimize boolean? `--optimize`
---@field ignore_case boolean? `--ignore-case`
---@field characters_as_bytes boolean? `--characters-as-bytes`
---@field use_lc_numeric boolean? `--use-lc-numeric`
-- Optional-value flags (true => flag only; string => `--flag=<value>`):
---@field debug boolean|string? gawk: `--debug[=flags]`
---@field profile boolean|string? gawk: `--profile[=file]`
---@field pretty_print boolean|string? gawk: `--pretty-print[=file]`
---@field dump_variables boolean|string? gawk: `--dump-variables[=file]`

---@class Awk
---@field bin string
---@field cmd fun(argv: string[]|nil): ward.Cmd
---@field eval fun(program: string, inputs: string|string[]|nil, opts: AwkOpts|nil): ward.Cmd
---@field source fun(programs: string|string[], inputs: string|string[]|nil, opts: AwkOpts|nil): ward.Cmd
---@field file fun(scripts: string|string[], inputs: string|string[]|nil, opts: AwkOpts|nil): ward.Cmd
local Awk = {
	bin = "awk",
}

---@param t any
---@return boolean
local function is_array(t)
	if type(t) ~= "table" then
		return false
	end
	local n = #t
	-- #t counts contiguous numeric keys from 1..n, but we still ensure no non-numeric keys
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

---@param v any
---@param label string
---@return string[]
local function as_string_list(v, label)
	if v == nil then
		return {}
	end
	if type(v) == "string" then
		return { v }
	end
	assert(type(v) == "table", label .. " must be a string or array")
	assert(is_array(v), label .. " must be an array")
	for _, s in ipairs(v) do
		validate.non_empty_string(s, label)
	end
	return v
end

---@param kv any
---@param label string
local function validate_kv_string(kv, label)
	validate.non_empty_string(kv, label)
	-- We deliberately do NOT enforce presence of '=' because some awk variants
	-- accept values that may be produced dynamically; consumer responsibility.
end

---@param args string[]
---@param opts AwkOpts|nil
local function apply_opts(args, opts)
	opts = opts or {}

	if opts.extra ~= nil then
		assert(type(opts.extra) == "table" and is_array(opts.extra), "extra must be an array")
		for _, x in ipairs(opts.extra) do
			validate.non_empty_string(x, "extra")
			table.insert(args, x)
		end
	end

	-- boolean long flags
	if opts.posix then
		table.insert(args, "--posix")
	end
	if opts.traditional then
		table.insert(args, "--traditional")
	end
	if opts.lint then
		table.insert(args, "--lint")
	end
	if opts.interval then
		table.insert(args, "--interval")
	end
	if opts.bignum then
		table.insert(args, "--bignum")
	end
	if opts.sandbox then
		table.insert(args, "--sandbox")
	end
	if opts.csv then
		table.insert(args, "--csv")
	end
	if opts.optimize then
		table.insert(args, "--optimize")
	end
	if opts.ignore_case then
		table.insert(args, "--ignore-case")
	end
	if opts.characters_as_bytes then
		table.insert(args, "--characters-as-bytes")
	end
	if opts.use_lc_numeric then
		table.insert(args, "--use-lc-numeric")
	end

	-- optional-value long flags
	local function opt_val(flag, v)
		if v == nil then
			return
		end
		if v == true then
			table.insert(args, flag)
			return
		end
		validate.non_empty_string(v, flag)
		table.insert(args, flag .. "=" .. v)
	end
	opt_val("--debug", opts.debug)
	opt_val("--profile", opts.profile)
	opt_val("--pretty-print", opts.pretty_print)
	opt_val("--dump-variables", opts.dump_variables)

	-- -F
	if opts.field_sep ~= nil then
		assert(type(opts.field_sep) == "string", "field_sep must be a string")
		table.insert(args, "-F")
		table.insert(args, opts.field_sep)
	end

	-- -i (gawk)
	if opts.includes ~= nil then
		assert(type(opts.includes) == "table" and is_array(opts.includes), "includes must be an array")
		for _, inc in ipairs(opts.includes) do
			validate.non_empty_string(inc, "include")
			table.insert(args, "-i")
			table.insert(args, inc)
		end
	end

	-- -v vars
	if opts.vars ~= nil then
		assert(type(opts.vars) == "table", "vars must be a table")
		if is_array(opts.vars) then
			for _, kv in ipairs(opts.vars) do
				validate_kv_string(kv, "var")
				table.insert(args, "-v")
				table.insert(args, kv)
			end
		else
			local keys = {}
			for k, _ in pairs(opts.vars) do
				validate.non_empty_string(k, "var name")
				table.insert(keys, k)
			end
			table.sort(keys)
			for _, k in ipairs(keys) do
				local v = opts.vars[k]
				assert(v ~= nil, "vars['" .. k .. "'] is nil")
				table.insert(args, "-v")
				table.insert(args, k .. "=" .. tostring(v))
			end
		end
	end
end

---@param args string[]
---@param assigns table
local function apply_assigns(args, assigns)
	assert(type(assigns) == "table", "assigns must be a table")
	if is_array(assigns) then
		for _, kv in ipairs(assigns) do
			validate_kv_string(kv, "assign")
			table.insert(args, kv)
		end
		return
	end

	local keys = {}
	for k, _ in pairs(assigns) do
		validate.non_empty_string(k, "assign name")
		table.insert(keys, k)
	end
	table.sort(keys)
	for _, k in ipairs(keys) do
		local v = assigns[k]
		assert(v ~= nil, "assigns['" .. k .. "'] is nil")
		table.insert(args, k .. "=" .. tostring(v))
	end
end

-- Generic constructor.
---@param argv string[]|nil
---@return ward.Cmd
function Awk.cmd(argv)
	ensure.bin(Awk.bin, { label = 'awk binary' })
	argv = argv or {}
	assert(type(argv) == "table" and is_array(argv), "argv must be an array")
	local args = { Awk.bin }
	for _, a in ipairs(argv) do
		validate.non_empty_string(a, "argv")
		table.insert(args, a)
	end
	return _cmd.cmd(table.unpack(args))
end

-- Inline program mode: awk [opts] 'program' [assigns...] [inputs...]
---@param program string
---@param inputs string|string[]|nil
---@param opts AwkOpts|nil
---@return ward.Cmd
function Awk.eval(program, inputs, opts)
	ensure.bin(Awk.bin, { label = 'awk binary' })
	validate.non_empty_string(program, "program")

	local args = { Awk.bin }
	apply_opts(args, opts)

	table.insert(args, program)

	if opts and opts.assigns ~= nil then
		apply_assigns(args, opts.assigns)
	end

	for _, f in ipairs(as_string_list(inputs, "inputs")) do
		table.insert(args, f)
	end

	return _cmd.cmd(table.unpack(args))
end

-- Multiple programs mode: awk [opts] -e 'p1' -e 'p2' ... [assigns...] [inputs...]
---@param programs string|string[]
---@param inputs string|string[]|nil
---@param opts AwkOpts|nil
---@return ward.Cmd
function Awk.source(programs, inputs, opts)
	ensure.bin(Awk.bin, { label = 'awk binary' })
	local ps = as_string_list(programs, "programs")
	assert(#ps > 0, "programs must not be empty")

	local args = { Awk.bin }
	apply_opts(args, opts)

	for _, p in ipairs(ps) do
		validate.non_empty_string(p, "program")
		table.insert(args, "-e")
		table.insert(args, p)
	end

	if opts and opts.assigns ~= nil then
		apply_assigns(args, opts.assigns)
	end

	for _, f in ipairs(as_string_list(inputs, "inputs")) do
		table.insert(args, f)
	end

	return _cmd.cmd(table.unpack(args))
end

-- Script file mode: awk [opts] -f script1 -f script2 ... [assigns...] [inputs...]
---@param scripts string|string[]
---@param inputs string|string[]|nil
---@param opts AwkOpts|nil
---@return ward.Cmd
function Awk.file(scripts, inputs, opts)
	ensure.bin(Awk.bin, { label = 'awk binary' })
	local ss = as_string_list(scripts, "scripts")
	assert(#ss > 0, "scripts must not be empty")

	local args = { Awk.bin }
	apply_opts(args, opts)

	for _, s in ipairs(ss) do
		validate.non_empty_string(s, "script")
		table.insert(args, "-f")
		table.insert(args, s)
	end

	if opts and opts.assigns ~= nil then
		apply_assigns(args, opts.assigns)
	end

	for _, f in ipairs(as_string_list(inputs, "inputs")) do
		table.insert(args, f)
	end

	return _cmd.cmd(table.unpack(args))
end

return {
	Awk = Awk,
}
