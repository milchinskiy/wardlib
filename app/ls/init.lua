---@diagnostic disable: undefined-doc-name

-- ls wrapper module
--
-- Thin wrappers around `ls` that construct CLI invocations and return
-- `ward.process.cmd(...)` objects.
--
-- This module intentionally does not parse output.

local _cmd = require("ward.process")
local validate = require("util.validate")
local ensure = require("tools.ensure")
local args_util = require("util.args")

---@class LsOpts
---@field all boolean? `-a`
---@field almost_all boolean? `-A`
---@field long boolean? `-l`
---@field human boolean? `-h` (GNU; typically used with `-l`)
---@field classify boolean? `-F`
---@field one_per_line boolean? `-1`
---@field recursive boolean? `-R`
---@field directory boolean? `-d`
---@field reverse boolean? `-r`
---@field sort_time boolean? `-t`
---@field sort_size boolean? `-S` (GNU)
---@field no_sort boolean? `-U` (BSD) / `-f` (GNU) (use `extra` for portability)
---@field color 'auto'|'always'|'never'? GNU `--color=<mode>`; use `extra` on BSD/macOS
---@field time_style string? GNU `--time-style=<style>`
---@field extra string[]? Extra args appended after modeled options

---@class Ls
---@field bin string Executable name or path to `ls`
---@field list fun(paths: string|string[]|nil, opts: LsOpts|nil): ward.Cmd
---@field raw fun(argv: string|string[], opts: LsOpts|nil): ward.Cmd
local Ls = {
	bin = "ls",
}

---@param args string[]
---@param opts LsOpts|nil
local function apply_opts(args, opts)
	opts = opts or {}

	if opts.all and opts.almost_all then
		error("all and almost_all are mutually exclusive")
	end
	local sort_count = 0
	if opts.sort_time then
		sort_count = sort_count + 1
	end
	if opts.sort_size then
		sort_count = sort_count + 1
	end
	if opts.no_sort then
		sort_count = sort_count + 1
	end
	if sort_count > 1 then
		error("sort_time, sort_size, and no_sort are mutually exclusive")
	end

	local p = args_util.parser(args, opts)
	p:flag("all", "-a")
		:flag("almost_all", "-A")
		:flag("long", "-l")
		:flag("human", "-h")
		:flag("classify", "-F")
		:flag("one_per_line", "-1")
		:flag("recursive", "-R")
		:flag("directory", "-d")
		:flag("reverse", "-r")
		:flag("sort_time", "-t")
		:flag("sort_size", "-S")
		:flag("no_sort", "-U")

	p:value("color", "--color", {
		mode = "equals",
		validate = function(v, _)
			local s = tostring(v)
			if s ~= "auto" and s ~= "always" and s ~= "never" then
				error("color must be one of: 'auto', 'always', 'never'")
			end
		end,
	})
	p:value("time_style", "--time-style", { mode = "equals", validate = validate.non_empty_string })
	p:extra()
end

---List directory contents.
---
---Builds: `ls <opts...> -- [paths...]`
---
---If `paths` is nil, defaults to `{"."}`.
---@param paths string|string[]|nil
---@param opts LsOpts|nil
---@return ward.Cmd
function Ls.list(paths, opts)
	ensure.bin(Ls.bin, { label = "ls binary" })
	local args = { Ls.bin }
	apply_opts(args, opts)
	args[#args + 1] = "--"
	local list = paths and args_util.normalize_string_or_array(paths, "paths") or { "." }
	for _, p in ipairs(list) do
		args[#args + 1] = p
	end
	return _cmd.cmd(table.unpack(args))
end

---Low-level escape hatch.
---Builds: `ls <modeled-opts...> <argv...>`
---@param argv string|string[]
---@param opts LsOpts|nil
---@return ward.Cmd
function Ls.raw(argv, opts)
	ensure.bin(Ls.bin, { label = "ls binary" })
	local args = { Ls.bin }
	apply_opts(args, opts)
	local av = args_util.normalize_string_or_array(argv, "argv")
	for _, s in ipairs(av) do
		args[#args + 1] = s
	end
	return _cmd.cmd(table.unpack(args))
end

return {
	Ls = Ls,
}
