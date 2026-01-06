---@diagnostic disable: undefined-doc-name

-- wget wrapper module
--
-- Thin wrappers around `wget` that construct CLI invocations and return
-- `ward.process.cmd(...)` objects.
--
-- This module intentionally does not parse output; consumers can decide how to
-- execute returned commands and interpret results.

local _cmd = require("ward.process")
local validate = require("util.validate")
local args_util = require("util.args")
local tbl = require("util.table")

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

	if opts.quiet then
		table.insert(args, "-q")
	end
	if opts.verbose then
		table.insert(args, "-v")
	end
	if opts.no_verbose then
		table.insert(args, "-nv")
	end
	if opts.continue then
		table.insert(args, "-c")
	end
	if opts.timestamping then
		table.insert(args, "-N")
	end
	if opts.no_clobber then
		table.insert(args, "-nc")
	end
	if opts.spider then
		table.insert(args, "--spider")
	end
	if opts.no_check_certificate then
		table.insert(args, "--no-check-certificate")
	end
	if opts.inet4_only then
		table.insert(args, "-4")
	end
	if opts.inet6_only then
		table.insert(args, "-6")
	end

	if opts.timeout ~= nil then
		validate.number_non_negative(opts.timeout, "timeout")
		table.insert(args, "--timeout=" .. tostring(opts.timeout))
	end
	if opts.wait ~= nil then
		validate.number_non_negative(opts.wait, "wait")
		table.insert(args, "--wait=" .. tostring(opts.wait))
	end
	if opts.tries ~= nil then
		validate.number_non_negative(opts.tries, "tries")
		table.insert(args, "--tries=" .. tostring(opts.tries))
	end

	if opts.output_document ~= nil then
		validate.non_empty_string(opts.output_document, "output_document")
		table.insert(args, "-O")
		table.insert(args, opts.output_document)
	end
	if opts.directory_prefix ~= nil then
		validate.non_empty_string(opts.directory_prefix, "directory_prefix")
		table.insert(args, "-P")
		table.insert(args, opts.directory_prefix)
	end
	if opts.input_file ~= nil then
		validate.non_empty_string(opts.input_file, "input_file")
		table.insert(args, "-i")
		table.insert(args, opts.input_file)
	end
	if opts.user_agent ~= nil then
		validate.non_empty_string(opts.user_agent, "user_agent")
		table.insert(args, "-U")
		table.insert(args, opts.user_agent)
	end

	if opts.header ~= nil then
		local headers = {}
		if type(opts.header) == "string" then
			headers = { opts.header }
		elseif type(opts.header) == "table" then
			assert(#opts.header > 0, "header list must be non-empty")
			for _, h in ipairs(opts.header) do
				table.insert(headers, tostring(h))
			end
		else
			error("header must be string or string[]")
		end
		for _, h in ipairs(headers) do
			validate.non_empty_string(h, "header")
			table.insert(args, "--header=" .. h)
		end
	end

	if opts.method ~= nil then
		validate.not_flag(opts.method, "method")
		table.insert(args, "--method=" .. opts.method)
	end
	if opts.post_data ~= nil then
		validate.non_empty_string(opts.post_data, "post_data")
		table.insert(args, "--post-data=" .. opts.post_data)
	end
	if opts.post_file ~= nil then
		validate.non_empty_string(opts.post_file, "post_file")
		table.insert(args, "--post-file=" .. opts.post_file)
	end
	if opts.body_data ~= nil then
		validate.non_empty_string(opts.body_data, "body_data")
		table.insert(args, "--body-data=" .. opts.body_data)
	end
	if opts.body_file ~= nil then
		validate.non_empty_string(opts.body_file, "body_file")
		table.insert(args, "--body-file=" .. opts.body_file)
	end

	if opts.recursive then
		table.insert(args, "-r")
	end
	if opts.level ~= nil then
		validate.number_non_negative(opts.level, "level")
		table.insert(args, "-l")
		table.insert(args, tostring(opts.level))
	end
	if opts.no_parent then
		table.insert(args, "-np")
	end
	if opts.mirror then
		table.insert(args, "-m")
	end
	if opts.page_requisites then
		table.insert(args, "-p")
	end
	if opts.convert_links then
		table.insert(args, "-k")
	end
	if opts.adjust_extension then
		table.insert(args, "-E")
	end

	args_util.append_extra(args, opts.extra)
end

---Construct a wget command.
---
---If `urls` is nil, wget will run with only the configured options (useful with `-i`).
---
---@param urls string|string[]|nil
---@param opts WgetOpts|nil
---@return ward.Cmd
function Wget.fetch(urls, opts)
	validate.bin(Wget.bin, "wget binary")

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
