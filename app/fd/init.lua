---@diagnostic disable: undefined-doc-name

-- fd wrapper module
--
-- Thin wrappers around `fd` that construct CLI invocations and return
-- `ward.process.cmd(...)` objects.
--
-- This module intentionally does not parse output.

local _cmd = require("ward.process")
local validate = require("util.validate")
local ensure = require("tools.ensure")
local args_util = require("util.args")

---@class FdOpts
---@field hidden boolean? `-H, --hidden`
---@field no_ignore boolean? `-I, --no-ignore`
---@field unrestricted boolean? `-u, --unrestricted` (alias for `--hidden --no-ignore`)
---@field no_ignore_vcs boolean? `--no-ignore-vcs`
---@field follow boolean? `-L, --follow`
---@field absolute_path boolean? `-a, --absolute-path`
---@field full_path boolean? `-p, --full-path`
---@field print0 boolean? `-0, --print0`
---@field quiet boolean? `-q, --quiet`
---@field show_errors boolean? `--show-errors`
---@field glob boolean? `-g, --glob` (glob pattern)
---@field fixed_strings boolean? `-F, --fixed-strings` (literal substring)
---@field case_sensitive boolean? `-s, --case-sensitive`
---@field ignore_case boolean? `-i, --ignore-case`
---@field max_results integer? `--max-results <n>`
---@field max_depth integer? `-d, --max-depth <n>`
---@field min_depth integer? `--min-depth <n>`
---@field exact_depth integer? `--exact-depth <n>`
---@field type string|string[]? `-t, --type <kind>` (repeatable)
---@field extension string|string[]? `-e, --extension <ext>` (repeatable)
---@field exclude string|string[]? `-E, --exclude <glob>` (repeatable)
---@field size string? `-S, --size <size>`
---@field changed_within string? `--changed-within <date>`
---@field changed_before string? `--changed-before <date>`
---@field exec string|string[]? `-x, --exec <cmd...>`
---@field exec_batch string|string[]? `-X, --exec-batch <cmd...>`
---@field extra string[]? Extra args appended after modeled options

---@class Fd
---@field bin string Executable name or path to `fd`
---@field search fun(pattern: string|nil, paths: string|string[]|nil, opts: FdOpts|nil): ward.Cmd
---@field all fun(paths: string|string[]|nil, opts: FdOpts|nil): ward.Cmd Convenience: search for all entries
---@field raw fun(argv: string|string[], opts: FdOpts|nil): ward.Cmd Low-level escape hatch
local Fd = {
	bin = "fd",
}

---@param args string[]
---@param opts FdOpts|nil
local function apply_opts(args, opts)
	opts = opts or {}

	-- search mode
	local mode_count = 0
	if opts.glob then
		mode_count = mode_count + 1
	end
	if opts.fixed_strings then
		mode_count = mode_count + 1
	end
	if mode_count > 1 then
		error("glob and fixed_strings are mutually exclusive")
	end
	if opts.glob then
		args[#args + 1] = "-g"
	end
	if opts.fixed_strings then
		args[#args + 1] = "-F"
	end

	-- case
	if opts.case_sensitive and opts.ignore_case then
		error("case_sensitive and ignore_case are mutually exclusive")
	end
	if opts.case_sensitive then
		args[#args + 1] = "-s"
	end
	if opts.ignore_case then
		args[#args + 1] = "-i"
	end

	if opts.hidden then
		args[#args + 1] = "-H"
	end
	if opts.no_ignore then
		args[#args + 1] = "-I"
	end
	if opts.unrestricted then
		args[#args + 1] = "-u"
	end
	if opts.no_ignore_vcs then
		args[#args + 1] = "--no-ignore-vcs"
	end

	if opts.follow then
		args[#args + 1] = "-L"
	end
	if opts.absolute_path then
		args[#args + 1] = "-a"
	end
	if opts.full_path then
		args[#args + 1] = "-p"
	end
	if opts.print0 then
		args[#args + 1] = "-0"
	end
	if opts.quiet then
		args[#args + 1] = "-q"
	end
	if opts.show_errors then
		args[#args + 1] = "--show-errors"
	end

	if opts.max_results ~= nil then
		validate.integer_min(opts.max_results, "max_results", 1)
		args[#args + 1] = "--max-results"
		args[#args + 1] = tostring(opts.max_results)
	end
	if opts.max_depth ~= nil then
		validate.integer_min(opts.max_depth, "max_depth", 0)
		args[#args + 1] = "-d"
		args[#args + 1] = tostring(opts.max_depth)
	end
	if opts.min_depth ~= nil then
		validate.integer_min(opts.min_depth, "min_depth", 0)
		args[#args + 1] = "--min-depth"
		args[#args + 1] = tostring(opts.min_depth)
	end
	if opts.exact_depth ~= nil then
		validate.integer_min(opts.exact_depth, "exact_depth", 0)
		args[#args + 1] = "--exact-depth"
		args[#args + 1] = tostring(opts.exact_depth)
	end

	if opts.type ~= nil then
		args_util.add_repeatable(args, opts.type, "-t", "type")
	end
	if opts.extension ~= nil then
		args_util.add_repeatable(args, opts.extension, "-e", "extension")
	end
	if opts.exclude ~= nil then
		args_util.add_repeatable(args, opts.exclude, "-E", "exclude")
	end

	if opts.size ~= nil then
		validate.non_empty_string(opts.size, "size")
		args[#args + 1] = "-S"
		args[#args + 1] = tostring(opts.size)
	end
	if opts.changed_within ~= nil then
		validate.non_empty_string(opts.changed_within, "changed_within")
		args[#args + 1] = "--changed-within"
		args[#args + 1] = tostring(opts.changed_within)
	end
	if opts.changed_before ~= nil then
		validate.non_empty_string(opts.changed_before, "changed_before")
		args[#args + 1] = "--changed-before"
		args[#args + 1] = tostring(opts.changed_before)
	end

	if opts.exec ~= nil and opts.exec_batch ~= nil then
		error("exec and exec_batch are mutually exclusive")
	end
	if opts.exec ~= nil then
		local cmdv = args_util.normalize_string_or_array(opts.exec, "exec")
		args[#args + 1] = "-x"
		for _, s in ipairs(cmdv) do
			args[#args + 1] = s
		end
	end
	if opts.exec_batch ~= nil then
		local cmdv = args_util.normalize_string_or_array(opts.exec_batch, "exec_batch")
		args[#args + 1] = "-X"
		for _, s in ipairs(cmdv) do
			args[#args + 1] = s
		end
	end

	args_util.append_extra(args, opts.extra)
end

---Build an fd search command.
---
---Builds: `fd <opts...> [pattern] [paths...]`
---
---If `pattern` is nil, defaults to `"."` (match all). To match all entries
---explicitly, you can also pass `""` (empty string).
---@param pattern string|nil
---@param paths string|string[]|nil
---@param opts FdOpts|nil
---@return ward.Cmd
function Fd.search(pattern, paths, opts)
	ensure.bin(Fd.bin, { label = "fd binary" })

	local p = pattern
	if p == nil then
		p = "."
	end
	assert(type(p) == "string", "pattern must be a string")

	local args = { Fd.bin }
	apply_opts(args, opts)
	args[#args + 1] = p

	if paths ~= nil then
		local list = args_util.normalize_string_or_array(paths, "paths")
		for _, v in ipairs(list) do
			args[#args + 1] = v
		end
	end

	return _cmd.cmd(table.unpack(args))
end

---Convenience: list all entries.
---@param paths string|string[]|nil
---@param opts FdOpts|nil
---@return ward.Cmd
function Fd.all(paths, opts)
	return Fd.search(".", paths, opts)
end

---Low-level escape hatch.
---Builds: `fd <modeled-opts...> <argv...>`
---@param argv string|string[]
---@param opts FdOpts|nil
---@return ward.Cmd
function Fd.raw(argv, opts)
	ensure.bin(Fd.bin, { label = "fd binary" })
	local args = { Fd.bin }
	apply_opts(args, opts)
	local av = args_util.normalize_string_or_array(argv, "argv")
	for _, s in ipairs(av) do
		args[#args + 1] = s
	end
	return _cmd.cmd(table.unpack(args))
end

return {
	Fd = Fd,
}
