---@diagnostic disable: undefined-doc-name

-- awk wrapper module
--
-- Thin wrappers around `awk` that construct CLI invocations and return
-- `ward.process.cmd(...)` objects.
--
-- This wrapper is intentionally output-agnostic (it does not parse stdout).
-- Consumers decide how to execute returned commands and interpret results.

local _cmd = require("ward.process")
local args_util = require("wardlib.util.args")
local ensure = require("wardlib.tools.ensure")
local validate = require("wardlib.util.validate")

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
	if type(t) ~= "table" then return false end
	local n = #t
	-- #t counts contiguous numeric keys from 1..n, but we still ensure no non-numeric keys
	for k, _ in pairs(t) do
		if type(k) ~= "number" then return false end
		if k < 1 or k > n or k % 1 ~= 0 then return false end
	end
	return true
end

---@param v any
---@param label string
---@return string[]
local function as_string_list(v, label)
	if v == nil then return {} end
	if type(v) == "string" then return { v } end
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

	local p = args_util.parser(args, opts)
	-- extra argv before the program/scripts
	p:extra("extra")

	-- boolean long flags
	p:flag("posix", "--posix")
		:flag("traditional", "--traditional")
		:flag("lint", "--lint")
		:flag("interval", "--interval")
		:flag("bignum", "--bignum")
		:flag("sandbox", "--sandbox")
		:flag("csv", "--csv")
		:flag("optimize", "--optimize")
		:flag("ignore_case", "--ignore-case")
		:flag("characters_as_bytes", "--characters-as-bytes")
		:flag("use_lc_numeric", "--use-lc-numeric")

	-- optional-value long flags
	p:bool_or_equals("debug", "--debug", { label = "debug", validate = validate.non_empty_string })
		:bool_or_equals("profile", "--profile", { label = "profile", validate = validate.non_empty_string })
		:bool_or_equals(
			"pretty_print",
			"--pretty-print",
			{ label = "pretty_print", validate = validate.non_empty_string }
		)
		:bool_or_equals(
			"dump_variables",
			"--dump-variables",
			{ label = "dump_variables", validate = validate.non_empty_string }
		)

	-- -F
	if opts.field_sep ~= nil then
		assert(type(opts.field_sep) == "string", "field_sep must be a string")
		args[#args + 1] = "-F"
		args[#args + 1] = opts.field_sep
	end

	-- -i (gawk)
	p:repeatable("includes", "-i", { label = "include", validate = validate.non_empty_string })

	-- -v vars
	if opts.vars ~= nil then
		local vars_list = args_util.kv_list(opts.vars, "var")
		for _, kv in ipairs(vars_list) do
			validate_kv_string(kv, "var")
			args[#args + 1] = "-v"
			args[#args + 1] = kv
		end
	end
end

---@param args string[]
---@param assigns table
local function apply_assigns(args, assigns)
	local list = args_util.kv_list(assigns, "assign")
	for _, kv in ipairs(list) do
		validate_kv_string(kv, "assign")
		args[#args + 1] = kv
	end
end

-- Generic constructor.
---@param argv string[]|nil
---@return ward.Cmd
function Awk.cmd(argv)
	ensure.bin(Awk.bin, { label = "awk binary" })
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
	ensure.bin(Awk.bin, { label = "awk binary" })
	validate.non_empty_string(program, "program")

	local args = { Awk.bin }
	apply_opts(args, opts)

	table.insert(args, program)

	if opts and opts.assigns ~= nil then apply_assigns(args, opts.assigns) end

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
	ensure.bin(Awk.bin, { label = "awk binary" })
	local ps = as_string_list(programs, "programs")
	assert(#ps > 0, "programs must not be empty")

	local args = { Awk.bin }
	apply_opts(args, opts)

	for _, p in ipairs(ps) do
		validate.non_empty_string(p, "program")
		table.insert(args, "-e")
		table.insert(args, p)
	end

	if opts and opts.assigns ~= nil then apply_assigns(args, opts.assigns) end

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
	ensure.bin(Awk.bin, { label = "awk binary" })
	local ss = as_string_list(scripts, "scripts")
	assert(#ss > 0, "scripts must not be empty")

	local args = { Awk.bin }
	apply_opts(args, opts)

	for _, s in ipairs(ss) do
		validate.non_empty_string(s, "script")
		table.insert(args, "-f")
		table.insert(args, s)
	end

	if opts and opts.assigns ~= nil then apply_assigns(args, opts.assigns) end

	for _, f in ipairs(as_string_list(inputs, "inputs")) do
		table.insert(args, f)
	end

	return _cmd.cmd(table.unpack(args))
end

return {
	Awk = Awk,
}
