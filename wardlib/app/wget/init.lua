---@diagnostic disable: undefined-doc-name

-- wget wrapper module
--
-- Thin wrappers around `wget` that construct CLI invocations and return
-- `ward.process.cmd(...)` objects.
--
-- This module intentionally does not parse output; consumers can decide how to
-- execute returned commands and interpret results.

local _cmd = require("ward.process")
local args_util = require("wardlib.util.args")
local ensure = require("wardlib.tools.ensure")
local tbl = require("wardlib.util.table")
local validate = require("wardlib.util.validate")

---@class WgetOpts
---@field quiet boolean? `-q`
---@field verbose boolean? `-v`
---@field no_verbose boolean? `-nv`
---@field continue boolean? `-c`
---@field timestamping boolean? `-N`
---@field no_clobber boolean? `-nc`
---@field spider boolean? `--spider`
---@field output_document string? `-O <file>`
---@field directory_prefix string? `-P <dir>`
---@field input_file string? `-i <file>`
---@field user_agent string? `-U <ua>`
---@field header string|string[]? `--header=<h>` repeated
---@field post_data string? `--post-data=<data>`
---@field post_file string? `--post-file=<file>`
---@field method string? `--method=<method>`
---@field body_data string? `--body-data=<data>`
---@field body_file string? `--body-file=<file>`
---@field no_check_certificate boolean? `--no-check-certificate`
---@field inet4_only boolean? `-4`
---@field inet6_only boolean? `-6`
---@field timeout number? `--timeout=<sec>`
---@field wait number? `--wait=<sec>`
---@field tries number? `--tries=<n>`
---@field recursive boolean? `-r`
---@field level number? `-l <n>`
---@field no_parent boolean? `-np`
---@field mirror boolean? `-m`
---@field page_requisites boolean? `-p`
---@field convert_links boolean? `-k`
---@field adjust_extension boolean? `-E`
---@field extra string[]? Extra args appended after modeled options

---@class Wget
---@field bin string Executable name or path to `wget`
---@field fetch fun(urls: string|string[]|nil, opts: WgetOpts|nil): ward.Cmd
---@field download fun(url: string, out: string|nil, opts: WgetOpts|nil): ward.Cmd
---@field mirror_site fun(url: string, dir: string|nil, opts: WgetOpts|nil): ward.Cmd
local Wget = {
	bin = "wget",
}

---@param args string[]
---@param opts WgetOpts|nil
local function apply_opts(args, opts)
	opts = opts or {}

	local p = args_util.parser(args, opts)
	p:flag("quiet", "-q")
		:flag("verbose", "-v")
		:flag("no_verbose", "-nv")
		:flag("continue", "-c")
		:flag("timestamping", "-N")
		:flag("no_clobber", "-nc")
		:flag("spider", "--spider")
		:flag("no_check_certificate", "--no-check-certificate")
		:flag("inet4_only", "-4")
		:flag("inet6_only", "-6")

	p:value_number("timeout", "--timeout", { non_negative = true, mode = "equals" })
	p:value_number("wait", "--wait", { non_negative = true, mode = "equals" })
	p:value_number("tries", "--tries", { non_negative = true, mode = "equals" })

	p:value_string("output_document", "-O")
	p:value_string("directory_prefix", "-P")
	p:value_string("input_file", "-i")
	p:value_string("user_agent", "-U")

	p:repeatable("header", "--header", { mode = "equals", validate = validate.non_empty_string })
	p:value("method", "--method", { mode = "equals", validate = validate.not_flag })
	p:value("post_data", "--post-data", { mode = "equals", validate = validate.non_empty_string })
	p:value("post_file", "--post-file", { mode = "equals", validate = validate.non_empty_string })
	p:value("body_data", "--body-data", { mode = "equals", validate = validate.non_empty_string })
	p:value("body_file", "--body-file", { mode = "equals", validate = validate.non_empty_string })

	p:flag("recursive", "-r")
	p:value_number("level", "-l", { non_negative = true })
	p:flag("no_parent", "-np")
		:flag("mirror", "-m")
		:flag("page_requisites", "-p")
		:flag("convert_links", "-k")
		:flag("adjust_extension", "-E")

	p:extra()
end

---Construct a wget command.
---
---If `urls` is nil, wget will run with only the configured options (useful with `-i`).
---
---@param urls string|string[]|nil
---@param opts WgetOpts|nil
---@return ward.Cmd
function Wget.fetch(urls, opts)
	ensure.bin(Wget.bin, { label = "wget binary" })

	local args = { Wget.bin }
	apply_opts(args, opts)

	if urls ~= nil then
		if type(urls) == "string" then
			validate.non_empty_string(urls, "url")
			table.insert(args, urls)
		elseif type(urls) == "table" then
			assert(#urls > 0, "urls list must be non-empty")
			for _, u in ipairs(urls) do
				validate.non_empty_string(u, "url")
				table.insert(args, u)
			end
		else
			error("urls must be string, string[], or nil")
		end
	end

	return _cmd.cmd(table.unpack(args))
end

---Convenience: download a single URL.
---
---If `out` is provided, sets `-O <out>`.
---
---@param url string
---@param out string|nil
---@param opts WgetOpts|nil
---@return ward.Cmd
function Wget.download(url, out, opts)
	validate.non_empty_string(url, "url")
	local o = tbl.shallow_copy(opts)
	if out ~= nil then
		validate.non_empty_string(out, "out")
		o.output_document = out
	end
	return Wget.fetch(url, o)
end

---Convenience: mirror a site.
---
---Adds `-m` and optionally `-P <dir>`.
---
---@param url string
---@param dir string|nil
---@param opts WgetOpts|nil
---@return ward.Cmd
function Wget.mirror_site(url, dir, opts)
	validate.non_empty_string(url, "url")
	local o = tbl.shallow_copy(opts)
	o.mirror = true
	if dir ~= nil then
		validate.non_empty_string(dir, "dir")
		o.directory_prefix = dir
	end
	return Wget.fetch(url, o)
end

return {
	Wget = Wget,
}
