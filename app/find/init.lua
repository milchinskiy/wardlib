---@diagnostic disable: undefined-doc-name

-- find wrapper module
--
-- Thin wrappers around `find` that construct CLI invocations and return
-- `ward.process.cmd(...)` objects.
--
-- This module intentionally does not parse output.
-- GNU/BSD/BusyBox find variants differ; use `expr` or `extra_expr` for
-- anything not modeled here.

local _cmd = require("ward.process")
local validate = require("util.validate")
local args_util = require("util.args")

---@class FindOpts
---@field follow_mode 'P'|'L'|'H'? Filesystem traversal: `-P` (default), `-L`, `-H` (must be before paths)
---@field maxdepth integer? `-maxdepth <n>`
---@field mindepth integer? `-mindepth <n>`
---@field xdev boolean? `-xdev` (do not descend into other filesystems)
---@field depth boolean? `-depth` (process contents before dir)
---@field type string? `-type <c>`
---@field name string? `-name <pattern>`
---@field iname string? `-iname <pattern>`
---@field path string? `-path <pattern>`
---@field ipath string? `-ipath <pattern>`
---@field regex string? `-regex <pattern>`
---@field iregex string? `-iregex <pattern>`
---@field size string? `-size <n>`
---@field user string? `-user <name>`
---@field group string? `-group <name>`
---@field perm string? `-perm <mode>`
---@field mtime integer? `-mtime <n>`
---@field atime integer? `-atime <n>`
---@field ctime integer? `-ctime <n>`
---@field newer string? `-newer <file>`
---@field empty boolean? `-empty`
---@field readable boolean? `-readable`
---@field writable boolean? `-writable`
---@field executable boolean? `-executable`
---@field print0 boolean? `-print0`
---@field extra string[]? Extra argv inserted after the binary and traversal mode, before `--`
---@field extra_expr string[]? Extra expression tokens appended after modeled expression

---@class Find
---@field bin string Executable name or path to `find`
---@field run fun(paths: string|string[]|nil, expr: string|string[]|nil, opts: FindOpts|nil): ward.Cmd
---@field search fun(paths: string|string[]|nil, opts: FindOpts|nil): ward.Cmd Convenience: only modeled expression
---@field raw fun(argv: string|string[], opts: FindOpts|nil): ward.Cmd Low-level escape hatch
local Find = {
	bin = "find",
}

---@param args string[]
---@param opts FindOpts|nil
local function apply_start_opts(args, opts)
	opts = opts or {}
	if opts.follow_mode ~= nil then
		assert(type(opts.follow_mode) == "string", "follow_mode must be a string")
		if opts.follow_mode == "P" then
			args[#args + 1] = "-P"
		elseif opts.follow_mode == "L" then
			args[#args + 1] = "-L"
		elseif opts.follow_mode == "H" then
			args[#args + 1] = "-H"
		else
			error("follow_mode must be one of: 'P', 'L', 'H'")
		end
	end
	args_util.append_extra(args, opts.extra)
end

---@param opts FindOpts|nil
---@return string[]
local function build_expr(opts)
	opts = opts or {}
	local e = {}

	if opts.maxdepth ~= nil then
		validate.integer_min(opts.maxdepth, "maxdepth", 0)
		e[#e + 1] = "-maxdepth"
		e[#e + 1] = tostring(opts.maxdepth)
	end
	if opts.mindepth ~= nil then
		validate.integer_min(opts.mindepth, "mindepth", 0)
		e[#e + 1] = "-mindepth"
		e[#e + 1] = tostring(opts.mindepth)
	end
	if opts.xdev then
		e[#e + 1] = "-xdev"
	end
	if opts.depth then
		e[#e + 1] = "-depth"
	end

	if opts.type ~= nil then
		validate.non_empty_string(opts.type, "type")
		e[#e + 1] = "-type"
		e[#e + 1] = tostring(opts.type)
	end
	if opts.name ~= nil then
		validate.non_empty_string(opts.name, "name")
		e[#e + 1] = "-name"
		e[#e + 1] = tostring(opts.name)
	end
	if opts.iname ~= nil then
		validate.non_empty_string(opts.iname, "iname")
		e[#e + 1] = "-iname"
		e[#e + 1] = tostring(opts.iname)
	end
	if opts.path ~= nil then
		validate.non_empty_string(opts.path, "path")
		e[#e + 1] = "-path"
		e[#e + 1] = tostring(opts.path)
	end
	if opts.ipath ~= nil then
		validate.non_empty_string(opts.ipath, "ipath")
		e[#e + 1] = "-ipath"
		e[#e + 1] = tostring(opts.ipath)
	end
	if opts.regex ~= nil then
		validate.non_empty_string(opts.regex, "regex")
		e[#e + 1] = "-regex"
		e[#e + 1] = tostring(opts.regex)
	end
	if opts.iregex ~= nil then
		validate.non_empty_string(opts.iregex, "iregex")
		e[#e + 1] = "-iregex"
		e[#e + 1] = tostring(opts.iregex)
	end

	if opts.size ~= nil then
		validate.non_empty_string(opts.size, "size")
		e[#e + 1] = "-size"
		e[#e + 1] = tostring(opts.size)
	end
	if opts.user ~= nil then
		validate.non_empty_string(opts.user, "user")
		e[#e + 1] = "-user"
		e[#e + 1] = tostring(opts.user)
	end
	if opts.group ~= nil then
		validate.non_empty_string(opts.group, "group")
		e[#e + 1] = "-group"
		e[#e + 1] = tostring(opts.group)
	end
	if opts.perm ~= nil then
		validate.non_empty_string(opts.perm, "perm")
		e[#e + 1] = "-perm"
		e[#e + 1] = tostring(opts.perm)
	end

	if opts.mtime ~= nil then
		validate.integer(opts.mtime, "mtime")
		e[#e + 1] = "-mtime"
		e[#e + 1] = tostring(opts.mtime)
	end
	if opts.atime ~= nil then
		validate.integer(opts.atime, "atime")
		e[#e + 1] = "-atime"
		e[#e + 1] = tostring(opts.atime)
	end
	if opts.ctime ~= nil then
		validate.integer(opts.ctime, "ctime")
		e[#e + 1] = "-ctime"
		e[#e + 1] = tostring(opts.ctime)
	end
	if opts.newer ~= nil then
		validate.non_empty_string(opts.newer, "newer")
		e[#e + 1] = "-newer"
		e[#e + 1] = tostring(opts.newer)
	end

	if opts.empty then
		e[#e + 1] = "-empty"
	end
	if opts.readable then
		e[#e + 1] = "-readable"
	end
	if opts.writable then
		e[#e + 1] = "-writable"
	end
	if opts.executable then
		e[#e + 1] = "-executable"
	end

	if opts.print0 then
		e[#e + 1] = "-print0"
	end

	args_util.append_extra(e, opts.extra_expr)
	return e
end

---Build a find command.
---
---Builds: `find [(-P|-L|-H)] <extra...> -- [paths...] <modeled-expr...> <expr...>`
---
---If `paths` is nil, defaults to `{"."}`.
---If no action is provided, find assumes `-print`.
---@param paths string|string[]|nil
---@param expr string|string[]|nil Additional expression tokens.
---@param opts FindOpts|nil
---@return ward.Cmd
function Find.run(paths, expr, opts)
	validate.bin(Find.bin, "find binary")

	local args = { Find.bin }
	apply_start_opts(args, opts)
	args[#args + 1] = "--"

	local roots
	if paths == nil then
		roots = { "." }
	else
		roots = args_util.normalize_string_or_array(paths, "paths")
	end
	for _, p in ipairs(roots) do
		args[#args + 1] = p
	end

	local e = build_expr(opts)
	for _, tok in ipairs(e) do
		args[#args + 1] = tok
	end

	if expr ~= nil then
		local more = args_util.normalize_string_or_array(expr, "expr")
		for _, tok in ipairs(more) do
			args[#args + 1] = tok
		end
	end

	return _cmd.cmd(table.unpack(args))
end

---Convenience: only modeled expression.
---@param paths string|string[]|nil
---@param opts FindOpts|nil
---@return ward.Cmd
function Find.search(paths, opts)
	return Find.run(paths, nil, opts)
end

---Low-level escape hatch.
---Builds: `find <modeled-start-opts...> <argv...>`
---@param argv string|string[]
---@param opts FindOpts|nil
---@return ward.Cmd
function Find.raw(argv, opts)
	validate.bin(Find.bin, "find binary")
	local args = { Find.bin }
	apply_start_opts(args, opts)
	local av = args_util.normalize_string_or_array(argv, "argv")
	for _, s in ipairs(av) do
		args[#args + 1] = s
	end
	return _cmd.cmd(table.unpack(args))
end

return {
	Find = Find,
}
