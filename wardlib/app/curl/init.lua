---@diagnostic disable: undefined-doc-name

-- curl wrapper module
--
-- Thin wrappers around `curl` that construct CLI invocations and return
-- `ward.process.cmd(...)` objects.
--
-- This module intentionally does not parse output; consumers can decide how to
-- execute returned commands and interpret results.

local _cmd = require("ward.process")
local args_util = require("wardlib.util.args")
local ensure = require("wardlib.tools.ensure")
local tbl = require("wardlib.util.table")
local validate = require("wardlib.util.validate")

---@class CurlOpts
---@field silent boolean? `-s`
---@field show_error boolean? `-S`
---@field verbose boolean? `-v`
---@field fail boolean? `--fail`
---@field location boolean? `-L`
---@field head boolean? `-I`
---@field request string? `-X <method>`
---@field data string? `-d <data>`
---@field data_raw string? `--data-raw <data>`
---@field form string|string[]? `-F <name=content>` repeated
---@field user_agent string? `-A <ua>`
---@field header string|string[]? `-H <header>` repeated
---@field cookie string? `-b <cookie>`
---@field cookie_jar string? `-c <file>`
---@field output string? `-o <file>`
---@field remote_name boolean? `-O`
---@field remote_header_name boolean? `-J`
---@field insecure boolean? `-k`
---@field cacert string? `--cacert <file>`
---@field cert string? `--cert <cert[:passwd]>`
---@field key string? `--key <key>`
---@field connect_timeout number? `--connect-timeout <sec>`
---@field max_time number? `--max-time <sec>`
---@field retry number? `--retry <n>`
---@field compressed boolean? `--compressed`
---@field ipv4 boolean? `-4`
---@field ipv6 boolean? `-6`
---@field http1_1 boolean? `--http1.1`
---@field http2 boolean? `--http2`
---@field write_out string? `-w <format>`
---@field extra string[]? Extra args appended after modeled options

---@class Curl
---@field bin string Executable name or path to `curl`
---@field request fun(urls: string|string[]|nil, opts: CurlOpts|nil): ward.Cmd
---@field get fun(url: string, opts: CurlOpts|nil): ward.Cmd
---@field head fun(url: string, opts: CurlOpts|nil): ward.Cmd
---@field download fun(url: string, out: string|nil, opts: CurlOpts|nil): ward.Cmd
---@field post fun(url: string, data: string|nil, opts: CurlOpts|nil): ward.Cmd
local Curl = {
	bin = "curl",
}

---@param args string[]
---@param opts CurlOpts|nil
local function apply_opts(args, opts)
	opts = opts or {}

	local p = args_util.parser(args, opts)
	p:flag("silent", "-s")
		:flag("show_error", "-S")
		:flag("verbose", "-v")
		:flag("fail", "--fail")
		:flag("location", "-L")
		:flag("head", "-I")
		:flag("insecure", "-k")
		:flag("compressed", "--compressed")
		:flag("ipv4", "-4")
		:flag("ipv6", "-6")
		:flag("http1_1", "--http1.1")
		:flag("http2", "--http2")
		:flag("remote_name", "-O")
		:flag("remote_header_name", "-J")

	p:value_token("request", "-X")
	p:value_number("connect_timeout", "--connect-timeout", { non_negative = true })
	p:value_number("max_time", "--max-time", { non_negative = true })
	p:value_number("retry", "--retry", { non_negative = true })

	p:value_string("user_agent", "-A")
	p:repeatable("header", "-H", { validate = validate.non_empty_string })
	p:value_string("cookie", "-b")
	p:value_string("cookie_jar", "-c")
	p:value_string("output", "-o")
	p:value_string("data", "-d")
	p:value_string("data_raw", "--data-raw")
	p:repeatable("form", "-F", { validate = validate.non_empty_string })
	p:value_string("cacert", "--cacert")
	p:value_string("cert", "--cert")
	p:value_string("key", "--key")
	p:value_string("write_out", "-w")
	p:extra()
end

---Construct a curl command.
---
---If `urls` is nil, curl will run with only the configured options.
---
---@param urls string|string[]|nil
---@param opts CurlOpts|nil
---@return ward.Cmd
function Curl.request(urls, opts)
	ensure.bin(Curl.bin, { label = "curl binary" })

	local args = { Curl.bin }
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

---@param url string
---@param opts CurlOpts|nil
---@return ward.Cmd
function Curl.get(url, opts)
	validate.non_empty_string(url, "url")
	return Curl.request(url, opts)
end

---@param url string
---@param opts CurlOpts|nil
---@return ward.Cmd
function Curl.head(url, opts)
	validate.non_empty_string(url, "url")
	local o = tbl.shallow_copy(opts)
	o.head = true
	return Curl.request(url, o)
end

---Convenience: download a URL.
---
---If `out` is provided, sets `-o <out>`. Otherwise uses `-O`.
---
---@param url string
---@param out string|nil
---@param opts CurlOpts|nil
---@return ward.Cmd
function Curl.download(url, out, opts)
	validate.non_empty_string(url, "url")
	local o = tbl.shallow_copy(opts)
	o.location = (o.location ~= false) and true or false
	if out ~= nil then
		validate.non_empty_string(out, "out")
		o.output = out
	else
		o.remote_name = true
	end
	return Curl.request(url, o)
end

---Convenience: POST a body.
---
---@param url string
---@param data string|nil
---@param opts CurlOpts|nil
---@return ward.Cmd
function Curl.post(url, data, opts)
	validate.non_empty_string(url, "url")
	local o = tbl.shallow_copy(opts)
	o.request = o.request or "POST"
	if data ~= nil then
		validate.non_empty_string(data, "data")
		o.data = data
	end
	return Curl.request(url, o)
end

return {
	Curl = Curl,
}
