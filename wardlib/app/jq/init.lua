---@diagnostic disable: undefined-doc-name

-- jq wrapper module
--
-- Thin wrappers around `jq` that construct CLI invocations and return
-- `ward.process.cmd(...)` objects.
--
-- This module intentionally does not parse output.

local _cmd = require("ward.process")
local validate = require("wardlib.util.validate")
local ensure = require("wardlib.tools.ensure")
local args_util = require("wardlib.util.args")

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

---@param args string[]
---@param opts JqOpts|nil
local function apply_opts(args, opts)
	opts = opts or {}

	-- preserve wrapper error text
	if opts.color_output and opts.monochrome_output then
		error("color_output and monochrome_output are mutually exclusive")
	end

	local p = args_util.parser(args, opts)

	-- input
	p:flag("null_input", "-n"):flag("raw_input", "-R"):flag("slurp", "-s")

	-- output controls
	p:flag("compact_output", "-c")
		:flag("raw_output", "-r")
		:flag("join_output", "-j")
		:flag("sort_keys", "-S")
		:flag("monochrome_output", "-M")
		:flag("color_output", "-C")
		:flag("exit_status", "-e")
		:flag("ascii_output", "-a")

	-- formatting
	p:flag("tab", "--tab"):value_number("indent", "--indent", { integer = true, min = 0, label = "indent" })

	-- Variable bindings. Stable-sorted for deterministic argv.
	p:repeatable_map("arg", "--arg", {
		label = "arg",
		validate_key = function(k, l)
			validate_var_name(k, l .. " name")
		end,
	})
	p:repeatable_map("argjson", "--argjson", {
		label = "argjson",
		validate_key = function(k, l)
			validate_var_name(k, l .. " name")
		end,
	})
	p:repeatable_map("slurpfile", "--slurpfile", {
		label = "slurpfile",
		validate_key = function(k, l)
			validate_var_name(k, l .. " name")
		end,
	})
	p:repeatable_map("rawfile", "--rawfile", {
		label = "rawfile",
		validate_key = function(k, l)
			validate_var_name(k, l .. " name")
		end,
	})

	p:extra()
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
