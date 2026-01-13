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
local ensure = require("wardlib.tools.ensure")
local args_util = require("wardlib.util.args")

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

	-- extra argv inserted after the binary and traversal mode, before `--`
	args_util.parser(args, opts):extra("extra")
end

---@param opts FindOpts|nil
---@return string[]
local function build_expr(opts)
	opts = opts or {}
	local e = {}

	local p = args_util.parser(e, opts)

	p:value_number("maxdepth", "-maxdepth", { integer = true, min = 0, label = "maxdepth" })
		:value_number("mindepth", "-mindepth", { integer = true, min = 0, label = "mindepth" })
		:flag("xdev", "-xdev")
		:flag("depth", "-depth")
		:value_string("type", "-type", "type")
		:value_string("name", "-name", "name")
		:value_string("iname", "-iname", "iname")
		:value_string("path", "-path", "path")
		:value_string("ipath", "-ipath", "ipath")
		:value_string("regex", "-regex", "regex")
		:value_string("iregex", "-iregex", "iregex")
		:value_string("size", "-size", "size")
		:value_string("user", "-user", "user")
		:value_string("group", "-group", "group")
		:value_string("perm", "-perm", "perm")
		:value_number("mtime", "-mtime", { integer = true, label = "mtime" })
		:value_number("atime", "-atime", { integer = true, label = "atime" })
		:value_number("ctime", "-ctime", { integer = true, label = "ctime" })
		:value_string("newer", "-newer", "newer")
		:flag("empty", "-empty")
		:flag("readable", "-readable")
		:flag("writable", "-writable")
		:flag("executable", "-executable")
		:flag("print0", "-print0")
		:extra("extra_expr")

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
	ensure.bin(Find.bin, { label = "find binary" })

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
	ensure.bin(Find.bin, { label = "find binary" })
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
