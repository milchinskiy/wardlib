---@diagnostic disable: undefined-doc-name

-- rg wrapper module (ripgrep)
--
-- Thin wrappers around `rg` that construct CLI invocations and return
-- `ward.process.cmd(...)` objects.
--
-- This module intentionally does not parse output.

local _cmd = require("ward.process")
local validate = require("wardlib.util.validate")
local ensure = require("wardlib.tools.ensure")
local args_util = require("wardlib.util.args")

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

	if opts.no_filename and opts.with_filename then
		error("no_filename and with_filename are mutually exclusive")
	end

	-- context
	if opts.context ~= nil and (opts.after_context ~= nil or opts.before_context ~= nil) then
		error("context is mutually exclusive with after_context/before_context")
	end

	local p = args_util.parser(args, opts)

	p:flag("fixed", "-F")
		:flag("ignore_case", "-i")
		:flag("smart_case", "-S")
		:flag("case_sensitive", "-s")
		:flag("word", "-w")
		:flag("line", "-x")
		:flag("invert", "-v")
		:flag("count", "-c")
		:flag("count_matches", "--count-matches")
		:flag("quiet", "-q")
		:flag("line_number", "-n")
		:flag("column", "--column")
		:flag("heading", "--heading")
		:flag("no_filename", "--no-filename")
		:flag("with_filename", "--with-filename")
		:flag("vimgrep", "--vimgrep")
		:flag("json", "--json")
		:value_number("after_context", "-A", { label = "after_context", integer = true, min = 0 })
		:value_number("before_context", "-B", { label = "before_context", integer = true, min = 0 })
		:value_number("context", "-C", { label = "context", integer = true, min = 0 })
		:value_number("max_count", "-m", { label = "max_count", integer = true, min = 1 })
		:value_number("threads", "-j", { label = "threads", integer = true, min = 1 })
		:flag("follow", "-L")
		:flag("hidden", "--hidden")
		:flag("no_ignore", "--no-ignore")
		:flag("no_ignore_vcs", "--no-ignore-vcs")
		:repeatable("glob", "-g", { label = "glob" })
		:repeatable("type", "--type", { label = "type" })
		:repeatable("type_not", "--type-not", { label = "type_not" })
		:flag("files_with_matches", "--files-with-matches")
		:flag("files_without_match", "--files-without-match")
		:value_string("replace", "-r", "replace")

	-- color
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

	p:extra("extra")
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
	ensure.bin(Rg.bin, { label = "rg binary" })

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
	ensure.bin(Rg.bin, { label = "rg binary" })
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
	ensure.bin(Rg.bin, { label = "rg binary" })
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
