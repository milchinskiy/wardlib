---@diagnostic disable: undefined-doc-name

-- grep wrapper module
--
-- Thin wrappers around `grep` that construct CLI invocations and return
-- `ward.process.cmd(...)` objects.
--
-- This module intentionally does not parse output.
-- For grep variants (GNU/BSD/BusyBox), some flags may differ; use `extra`
-- for anything not modeled here.

local _cmd = require("ward.process")
local args_util = require("wardlib.util.args")
local ensure = require("wardlib.tools.ensure")
local validate = require("wardlib.util.validate")

---@class GrepOpts
---@field extended boolean? `-E` (ERE)
---@field fixed boolean? `-F` (fixed strings)
---@field perl boolean? `-P` (PCRE, GNU grep)
---@field ignore_case boolean? `-i`
---@field word boolean? `-w` (word-regexp)
---@field line boolean? `-x` (line-regexp)
---@field invert boolean? `-v`
---@field count boolean? `-c`
---@field quiet boolean? `-q`
---@field line_number boolean? `-n`
---@field files_with_matches boolean? `-l`
---@field files_without_matches boolean? `-L`
---@field with_filename boolean? `-H`
---@field no_filename boolean? `-h`
---@field recursive boolean? `-r`
---@field recursive_follow boolean? `-R`
---@field max_count number? `-m <n>`
---@field after_context number? `-A <n>`
---@field before_context number? `-B <n>`
---@field context number? `-C <n>`
---@field null boolean? `-Z` (print NUL after file name; GNU/BSD)
---@field null_data boolean? `-z` (treat input as NUL-separated; GNU)
---@field text boolean? `-a` (process binary as text)
---@field binary_without_match boolean? `-I` (ignore binary files)
---@field color boolean|string? `--color[=WHEN]` (GNU) If true uses `auto`.
---@field include string|string[]? `--include=<glob>` (GNU)
---@field exclude string|string[]? `--exclude=<glob>` (GNU)
---@field exclude_dir string|string[]? `--exclude-dir=<glob>` (GNU)
---@field extra string[]? Extra args appended after modeled options

---@class Grep
---@field bin string Executable name or path to `grep`
---@field search fun(pattern: string|string[], inputs: string|string[]|nil, opts: GrepOpts|nil): ward.Cmd
---@field count_matches fun(pattern: string|string[], inputs: string|string[]|nil, opts: GrepOpts|nil): ward.Cmd Convenience: sets `-c`
---@field list_files fun(pattern: string|string[], inputs: string|string[]|nil, opts: GrepOpts|nil): ward.Cmd Convenience: sets `-l`
---@field raw fun(argv: string|string[], opts: GrepOpts|nil): ward.Cmd Low-level escape hatch
local Grep = {
	bin = "grep",
}

---@param args string[]
---@param opts GrepOpts|nil
local function apply_opts(args, opts)
	opts = opts or {}

	-- matcher selection
	local matcher_count = 0
	if opts.extended then matcher_count = matcher_count + 1 end
	if opts.fixed then matcher_count = matcher_count + 1 end
	if opts.perl then matcher_count = matcher_count + 1 end
	if matcher_count > 1 then error("extended/fixed/perl are mutually exclusive") end
	if opts.extended then
		args[#args + 1] = "-E"
	elseif opts.fixed then
		args[#args + 1] = "-F"
	elseif opts.perl then
		args[#args + 1] = "-P"
	end

	if opts.with_filename and opts.no_filename then error("with_filename and no_filename are mutually exclusive") end

	if opts.recursive and opts.recursive_follow then error("recursive and recursive_follow are mutually exclusive") end

	-- context
	if opts.context ~= nil and (opts.after_context ~= nil or opts.before_context ~= nil) then
		error("context is mutually exclusive with after_context/before_context")
	end

	local p = args_util.parser(args, opts)
	p:flag("ignore_case", "-i")
		:flag("word", "-w")
		:flag("line", "-x")
		:flag("invert", "-v")
		:flag("count", "-c")
		:flag("quiet", "-q")
		:flag("line_number", "-n")
		:flag("files_with_matches", "-l")
		:flag("files_without_matches", "-L")
		:flag("with_filename", "-H")
		:flag("no_filename", "-h")
		:flag("recursive", "-r")
		:flag("recursive_follow", "-R")
		:value_number("max_count", "-m", { min = 1 })
		:value_number("after_context", "-A", { min = 0 })
		:value_number("before_context", "-B", { min = 0 })
		:value_number("context", "-C", { min = 0 })
		:flag("null", "-Z")
		:flag("null_data", "-z")
		:flag("text", "-a")
		:flag("binary_without_match", "-I")

	if opts.color ~= nil then
		if opts.color == true then
			args[#args + 1] = "--color=auto"
		elseif type(opts.color) == "string" then
			validate.not_flag(opts.color, "color")
			args[#args + 1] = "--color=" .. opts.color
		else
			error("color must be boolean or string")
		end
	end

	p:repeatable("include", "--include", { mode = "equals" })
	p:repeatable("exclude", "--exclude", { mode = "equals" })
	p:repeatable("exclude_dir", "--exclude-dir", { mode = "equals" })
	p:extra()
end

---@param args string[]
---@param inputs string|string[]|nil
local function apply_inputs(args, inputs)
	if inputs == nil then return end
	local list = args_util.normalize_string_or_array(inputs, "inputs")
	for _, p in ipairs(list) do
		validate.not_flag(p, "input")
		args[#args + 1] = p
	end
end

---Build a grep search command.
---
---Patterns are always emitted using `-e <pattern>` (possibly repeated) to avoid
---ambiguity when patterns start with `-`.
---@param pattern string|string[]
---@param inputs string|string[]|nil If nil, grep reads stdin.
---@param opts GrepOpts|nil
---@return ward.Cmd
function Grep.search(pattern, inputs, opts)
	ensure.bin(Grep.bin, { label = "grep binary" })

	local args = { Grep.bin }
	apply_opts(args, opts)
	args_util.add_repeatable(args, pattern, "-e", "pattern")
	apply_inputs(args, inputs)
	return _cmd.cmd(table.unpack(args))
end

---Convenience: `grep -c`.
---@param pattern string|string[]
---@param inputs string|string[]|nil
---@param opts GrepOpts|nil
---@return ward.Cmd
function Grep.count_matches(pattern, inputs, opts)
	local o = args_util.clone_opts(opts)
	o.count = true
	return Grep.search(pattern, inputs, o)
end

---Convenience: `grep -l`.
---@param pattern string|string[]
---@param inputs string|string[]|nil
---@param opts GrepOpts|nil
---@return ward.Cmd
function Grep.list_files(pattern, inputs, opts)
	local o = args_util.clone_opts(opts)
	o.files_with_matches = true
	return Grep.search(pattern, inputs, o)
end

---Low-level escape hatch.
---Builds: `grep <modeled-opts...> <argv...>`
---@param argv string|string[]
---@param opts GrepOpts|nil
---@return ward.Cmd
function Grep.raw(argv, opts)
	ensure.bin(Grep.bin, { label = "grep binary" })
	local args = { Grep.bin }
	apply_opts(args, opts)
	local av = args_util.normalize_string_or_array(argv, "argv")
	for _, s in ipairs(av) do
		args[#args + 1] = s
	end
	return _cmd.cmd(table.unpack(args))
end

return {
	Grep = Grep,
}
