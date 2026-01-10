---@diagnostic disable: undefined-doc-name

-- rg wrapper module (ripgrep)
--
-- Thin wrappers around `rg` that construct CLI invocations and return
-- `ward.process.cmd(...)` objects.
--
-- This module intentionally does not parse output.

local _cmd = require("ward.process")
local validate = require("util.validate")
local args_util = require("util.args")

---@class RgOpts
---@field fixed boolean? `-F` (fixed strings)
---@field ignore_case boolean? `-i`
---@field smart_case boolean? `-S`
---@field case_sensitive boolean? `-s`
---@field word boolean? `-w`
---@field line boolean? `-x`
---@field invert boolean? `-v`
---@field count boolean? `-c` (count matching lines)
---@field count_matches boolean? `--count-matches`
---@field quiet boolean? `-q`
---@field line_number boolean? `-n`
---@field column boolean? `--column`
---@field heading boolean? `--heading`
---@field no_filename boolean? `--no-filename`
---@field with_filename boolean? `--with-filename`
---@field vimgrep boolean? `--vimgrep`
---@field json boolean? `--json`
---@field after_context number? `-A <n>`
---@field before_context number? `-B <n>`
---@field context number? `-C <n>`
---@field max_count number? `-m <n>`
---@field threads number? `-j <n>`
---@field follow boolean? `-L` (follow symlinks)
---@field hidden boolean? `--hidden`
---@field no_ignore boolean? `--no-ignore`
---@field no_ignore_vcs boolean? `--no-ignore-vcs`
---@field glob string|string[]? `-g <glob>` (repeatable)
---@field type string|string[]? `--type <type>` (repeatable)
---@field type_not string|string[]? `--type-not <type>` (repeatable)
---@field files_with_matches boolean? `--files-with-matches`
---@field files_without_match boolean? `--files-without-match`
---@field replace string? `-r <replacement>`
---@field color boolean|string? `--color[=WHEN]` If true uses `auto`.
---@field extra string[]? Extra args appended after modeled options

---@class Rg
---@field bin string Executable name or path to `rg`
---@field search fun(pattern: string|string[], paths: string|string[]|nil, opts: RgOpts|nil): ward.Cmd
---@field files fun(paths: string|string[]|nil, opts: RgOpts|nil): ward.Cmd Convenience: `rg --files`
---@field raw fun(argv: string|string[], opts: RgOpts|nil): ward.Cmd Low-level escape hatch
local Rg = {
	bin = "rg",
}

---@param args string[]
---@param opts RgOpts|nil
local function apply_opts(args, opts)
	opts = opts or {}

	if opts.fixed then
		args[#args + 1] = "-F"
	end

	if opts.ignore_case then
		args[#args + 1] = "-i"
	end
	if opts.smart_case then
		args[#args + 1] = "-S"
	end
	if opts.case_sensitive then
		args[#args + 1] = "-s"
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
	if opts.count_matches then
		args[#args + 1] = "--count-matches"
	end
	if opts.quiet then
		args[#args + 1] = "-q"
	end

	if opts.line_number then
		args[#args + 1] = "-n"
	end
	if opts.column then
		args[#args + 1] = "--column"
	end
	if opts.heading then
		args[#args + 1] = "--heading"
	end
	if opts.no_filename and opts.with_filename then
		error("no_filename and with_filename are mutually exclusive")
	end
	if opts.no_filename then
		args[#args + 1] = "--no-filename"
	end
	if opts.with_filename then
		args[#args + 1] = "--with-filename"
	end
	if opts.vimgrep then
		args[#args + 1] = "--vimgrep"
	end
	if opts.json then
		args[#args + 1] = "--json"
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
	if opts.max_count ~= nil then
		validate.number_min(opts.max_count, "max_count", 1)
		args[#args + 1] = "-m"
		args[#args + 1] = tostring(opts.max_count)
	end
	if opts.threads ~= nil then
		validate.number_min(opts.threads, "threads", 1)
		args[#args + 1] = "-j"
		args[#args + 1] = tostring(opts.threads)
	end

	if opts.follow then
		args[#args + 1] = "-L"
	end
	if opts.hidden then
		args[#args + 1] = "--hidden"
	end
	if opts.no_ignore then
		args[#args + 1] = "--no-ignore"
	end
	if opts.no_ignore_vcs then
		args[#args + 1] = "--no-ignore-vcs"
	end

	if opts.glob ~= nil then
		args_util.add_repeatable(args, opts.glob, "-g", "glob")
	end
	if opts.type ~= nil then
		args_util.add_repeatable(args, opts.type, "--type", "type")
	end
	if opts.type_not ~= nil then
		args_util.add_repeatable(args, opts.type_not, "--type-not", "type_not")
	end

	if opts.files_with_matches then
		args[#args + 1] = "--files-with-matches"
	end
	if opts.files_without_match then
		args[#args + 1] = "--files-without-match"
	end

	if opts.replace ~= nil then
		validate.non_empty_string(opts.replace, "replace")
		args[#args + 1] = "-r"
		args[#args + 1] = tostring(opts.replace)
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

	args_util.append_extra(args, opts.extra)
end

---@param args string[]
---@param paths string|string[]|nil
local function apply_paths(args, paths)
	if paths == nil then
		return
	end
	local list = args_util.normalize_string_or_array(paths, "paths")
	for _, p in ipairs(list) do
		validate.not_flag(p, "path")
		args[#args + 1] = p
	end
end

---Build an rg search command.
---
---Patterns are always emitted using `-e <pattern>` (possibly repeated) to avoid
---ambiguity when patterns start with `-`.
---@param pattern string|string[]
---@param paths string|string[]|nil If nil, rg searches current directory.
---@param opts RgOpts|nil
---@return ward.Cmd
function Rg.search(pattern, paths, opts)
	validate.bin(Rg.bin, "rg binary")

	local args = { Rg.bin }
	apply_opts(args, opts)
	args_util.add_repeatable(args, pattern, "-e", "pattern")
	apply_paths(args, paths)
	return _cmd.cmd(table.unpack(args))
end

---Convenience: list files rg would search.
---@param paths string|string[]|nil
---@param opts RgOpts|nil
---@return ward.Cmd
function Rg.files(paths, opts)
	validate.bin(Rg.bin, "rg binary")
	local args = { Rg.bin }
	apply_opts(args, opts)
	args[#args + 1] = "--files"
	apply_paths(args, paths)
	return _cmd.cmd(table.unpack(args))
end

---Low-level escape hatch.
---Builds: `rg <modeled-opts...> <argv...>`
---@param argv string|string[]
---@param opts RgOpts|nil
---@return ward.Cmd
function Rg.raw(argv, opts)
	validate.bin(Rg.bin, "rg binary")
	local args = { Rg.bin }
	apply_opts(args, opts)
	local av = args_util.normalize_string_or_array(argv, "argv")
	for _, s in ipairs(av) do
		args[#args + 1] = s
	end
	return _cmd.cmd(table.unpack(args))
end

return {
	Rg = Rg,
}
