---@diagnostic disable: undefined-doc-name

-- jq wrapper module
--
-- Thin wrappers around `jq` that construct CLI invocations and return
-- `ward.process.cmd(...)` objects.
--
-- This module intentionally does not parse output.

local _cmd = require("ward.process")
local validate = require("util.validate")
local ensure = require("tools.ensure")
local args_util = require("util.args")

---@class JqOpts
---@field null_input boolean? `-n` (use null input)
---@field raw_input boolean? `-R` (read raw strings, not JSON)
---@field slurp boolean? `-s` (read all inputs into an array)
---@field compact_output boolean? `-c`
---@field raw_output boolean? `-r`
---@field join_output boolean? `-j`
---@field sort_keys boolean? `-S`
---@field monochrome_output boolean? `-M`
---@field color_output boolean? `-C`
---@field exit_status boolean? `-e` (set exit status based on output)
---@field ascii_output boolean? `-a`
---@field tab boolean? `--tab`
---@field indent integer? `--indent <n>`
---@field arg table<string,string>? `--arg <name> <value>` (repeatable, stable-sorted)
---@field argjson table<string,string>? `--argjson <name> <json>` (repeatable, stable-sorted)
---@field slurpfile table<string,string>? `--slurpfile <name> <file>` (repeatable, stable-sorted)
---@field rawfile table<string,string>? `--rawfile <name> <file>` (repeatable, stable-sorted)
---@field extra string[]? Extra args appended after modeled options (before filter)

---@class Jq
---@field bin string Executable name or path to `jq`
---@field eval fun(filter: string|nil, inputs: string|string[]|nil, opts: JqOpts|nil): ward.Cmd
---@field eval_file fun(file: string, inputs: string|string[]|nil, opts: JqOpts|nil): ward.Cmd
---@field eval_stdin fun(filter: string|nil, data: string, opts: JqOpts|nil): ward.Cmd
---@field raw fun(argv: string|string[], opts: JqOpts|nil): ward.Cmd
local Jq = {
	bin = "jq",
}

---@param name string
---@param label string
local function validate_var_name(name, label)
	validate.non_empty_string(name, label)
	assert(name:match("^[%a_][%w_]*$") ~= nil, label .. " must match ^[A-Za-z_][A-Za-z0-9_]*$: " .. tostring(name))
end

---@param m table<string,string>
---@return string[]
local function sorted_keys(m)
	local keys = {}
	for k, _ in pairs(m) do
		keys[#keys + 1] = k
	end
	table.sort(keys)
	return keys
end

---@param args string[]
---@param opts JqOpts|nil
local function apply_opts(args, opts)
	opts = opts or {}

	if opts.color_output and opts.monochrome_output then
		error("color_output and monochrome_output are mutually exclusive")
	end

	if opts.null_input then
		args[#args + 1] = "-n"
	end
	if opts.raw_input then
		args[#args + 1] = "-R"
	end
	if opts.slurp then
		args[#args + 1] = "-s"
	end

	if opts.compact_output then
		args[#args + 1] = "-c"
	end
	if opts.raw_output then
		args[#args + 1] = "-r"
	end
	if opts.join_output then
		args[#args + 1] = "-j"
	end
	if opts.sort_keys then
		args[#args + 1] = "-S"
	end
	if opts.monochrome_output then
		args[#args + 1] = "-M"
	end
	if opts.color_output then
		args[#args + 1] = "-C"
	end
	if opts.exit_status then
		args[#args + 1] = "-e"
	end
	if opts.ascii_output then
		args[#args + 1] = "-a"
	end

	if opts.tab then
		args[#args + 1] = "--tab"
	end
	if opts.indent ~= nil then
		validate.integer_min(opts.indent, "indent", 0)
		args[#args + 1] = "--indent"
		args[#args + 1] = tostring(opts.indent)
	end

	-- Variable bindings. We sort keys for deterministic argv.
	if opts.arg ~= nil then
		assert(type(opts.arg) == "table", "arg must be a table")
		for _, k in ipairs(sorted_keys(opts.arg)) do
			validate_var_name(k, "arg name")
			args[#args + 1] = "--arg"
			args[#args + 1] = k
			args[#args + 1] = tostring(opts.arg[k])
		end
	end
	if opts.argjson ~= nil then
		assert(type(opts.argjson) == "table", "argjson must be a table")
		for _, k in ipairs(sorted_keys(opts.argjson)) do
			validate_var_name(k, "argjson name")
			args[#args + 1] = "--argjson"
			args[#args + 1] = k
			args[#args + 1] = tostring(opts.argjson[k])
		end
	end
	if opts.slurpfile ~= nil then
		assert(type(opts.slurpfile) == "table", "slurpfile must be a table")
		for _, k in ipairs(sorted_keys(opts.slurpfile)) do
			validate_var_name(k, "slurpfile name")
			args[#args + 1] = "--slurpfile"
			args[#args + 1] = k
			args[#args + 1] = tostring(opts.slurpfile[k])
		end
	end
	if opts.rawfile ~= nil then
		assert(type(opts.rawfile) == "table", "rawfile must be a table")
		for _, k in ipairs(sorted_keys(opts.rawfile)) do
			validate_var_name(k, "rawfile name")
			args[#args + 1] = "--rawfile"
			args[#args + 1] = k
			args[#args + 1] = tostring(opts.rawfile[k])
		end
	end

	args_util.append_extra(args, opts.extra)
end

---@param args string[]
---@param inputs string|string[]|nil
local function apply_inputs(args, inputs)
	if inputs == nil then
		return
	end
	local list = args_util.normalize_string_or_array(inputs, "inputs")
	for _, p in ipairs(list) do
		validate.not_flag(p, "input")
		args[#args + 1] = p
	end
end

---Evaluate a jq filter.
---
---Builds: `jq <opts...> -- <filter> [inputs...]`
---
---If `inputs` is nil, jq reads stdin.
---@param filter string|nil If nil, defaults to "."
---@param inputs string|string[]|nil
---@param opts JqOpts|nil
---@return ward.Cmd
function Jq.eval(filter, inputs, opts)
	ensure.bin(Jq.bin, { label = "jq binary" })
	local f = filter or "."
	validate.non_empty_string(f, "filter")

	local args = { Jq.bin }
	apply_opts(args, opts)
	-- Explicit end-of-options to avoid ambiguity if filter starts with '-'
	args[#args + 1] = "--"
	args[#args + 1] = f
	apply_inputs(args, inputs)
	return _cmd.cmd(table.unpack(args))
end

---Evaluate a jq filter program from a file.
---
---Builds: `jq <opts...> -f <file> [inputs...]`
---@param file string
---@param inputs string|string[]|nil
---@param opts JqOpts|nil
---@return ward.Cmd
function Jq.eval_file(file, inputs, opts)
	ensure.bin(Jq.bin, { label = "jq binary" })
	validate.non_empty_string(file, "file")

	local args = { Jq.bin }
	apply_opts(args, opts)
	args[#args + 1] = "-f"
	args[#args + 1] = file
	apply_inputs(args, inputs)
	return _cmd.cmd(table.unpack(args))
end

---Evaluate a jq filter by feeding `data` via stdin.
---
---This is a convenience over `Jq.eval(filter, nil, opts)`.
---If the returned Cmd supports `:stdin(...)`, this function uses it.
---Otherwise it stores `stdin_data` on the returned object.
---@param filter string|nil If nil, defaults to "."
---@param data string
---@param opts JqOpts|nil
---@return ward.Cmd
function Jq.eval_stdin(filter, data, opts)
	local c = Jq.eval(filter, nil, opts)
	assert(type(data) == "string", "data must be a string")
	if type(c.stdin) == "function" then
		c:stdin(data)
	else
		c.stdin_data = data
	end
	return c
end

---Low-level escape hatch.
---Builds: `jq <modeled-opts...> <argv...>`
---@param argv string|string[]
---@param opts JqOpts|nil
---@return ward.Cmd
function Jq.raw(argv, opts)
	ensure.bin(Jq.bin, { label = "jq binary" })
	local args = { Jq.bin }
	apply_opts(args, opts)
	local av = args_util.normalize_string_or_array(argv, "argv")
	for _, s in ipairs(av) do
		args[#args + 1] = s
	end
	return _cmd.cmd(table.unpack(args))
end

return {
	Jq = Jq,
}
