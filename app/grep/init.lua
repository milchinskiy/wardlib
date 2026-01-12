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
local validate = require("util.validate")
local ensure = require("tools.ensure")
local args_util = require("util.args")

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
	if opts.extended then
		matcher_count = matcher_count + 1
	end
	if opts.fixed then
		matcher_count = matcher_count + 1
	end
	if opts.perl then
		matcher_count = matcher_count + 1
	end
	if matcher_count > 1 then
		error("extended/fixed/perl are mutually exclusive")
	end
	if opts.extended then
		args[#args + 1] = "-E"
	elseif opts.fixed then
		args[#args + 1] = "-F"
	elseif opts.perl then
		args[#args + 1] = "-P"
	end

	if opts.ignore_case then
		args[#args + 1] = "-i"
	end
	if opts.word then
		args[#args + 1] = "-w"
	end
	if opts.line then
		args[#args + 1] = "-x"
	end
	if opts.invert then
		args[#args + 1] = "-v"
	end

	if opts.count then
		args[#args + 1] = "-c"
	end
	if opts.quiet then
		args[#args + 1] = "-q"
	end
	if opts.line_number then
		args[#args + 1] = "-n"
	end
	if opts.files_with_matches then
		args[#args + 1] = "-l"
	end
	if opts.files_without_matches then
		args[#args + 1] = "-L"
	end

	if opts.with_filename and opts.no_filename then
		error("with_filename and no_filename are mutually exclusive")
	end
	if opts.with_filename then
		args[#args + 1] = "-H"
	end
	if opts.no_filename then
		args[#args + 1] = "-h"
	end

	if opts.recursive and opts.recursive_follow then
		error("recursive and recursive_follow are mutually exclusive")
	end
	if opts.recursive then
		args[#args + 1] = "-r"
	end
	if opts.recursive_follow then
		args[#args + 1] = "-R"
	end

	if opts.max_count ~= nil then
		validate.number_min(opts.max_count, "max_count", 1)
		args[#args + 1] = "-m"
		args[#args + 1] = tostring(opts.max_count)
	end

	-- context
	if opts.context ~= nil and (opts.after_context ~= nil or opts.before_context ~= nil) then
		error("context is mutually exclusive with after_context/before_context")
	end
	if opts.after_context ~= nil then
		validate.number_min(opts.after_context, "after_context", 0)
		args[#args + 1] = "-A"
		args[#args + 1] = tostring(opts.after_context)
	end
	if opts.before_context ~= nil then
		validate.number_min(opts.before_context, "before_context", 0)
		args[#args + 1] = "-B"
		args[#args + 1] = tostring(opts.before_context)
	end
	if opts.context ~= nil then
		validate.number_min(opts.context, "context", 0)
		args[#args + 1] = "-C"
		args[#args + 1] = tostring(opts.context)
	end

	if opts.null then
		args[#args + 1] = "-Z"
	end
	if opts.null_data then
		args[#args + 1] = "-z"
	end
	if opts.text then
		args[#args + 1] = "-a"
	end
	if opts.binary_without_match then
		args[#args + 1] = "-I"
	end

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

	if opts.include ~= nil then
		local inc = args_util.normalize_string_or_array(opts.include, "include")
		for _, g in ipairs(inc) do
			args[#args + 1] = "--include=" .. g
		end
	end
	if opts.exclude ~= nil then
		local exc = args_util.normalize_string_or_array(opts.exclude, "exclude")
		for _, g in ipairs(exc) do
			args[#args + 1] = "--exclude=" .. g
		end
	end
	if opts.exclude_dir ~= nil then
		local excd = args_util.normalize_string_or_array(opts.exclude_dir, "exclude_dir")
		for _, g in ipairs(excd) do
			args[#args + 1] = "--exclude-dir=" .. g
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
