---@diagnostic disable: undefined-doc-name

-- curl wrapper module
--
-- Thin wrappers around `curl` that construct CLI invocations and return
-- `ward.process.cmd(...)` objects.
--
-- This module intentionally does not parse output; consumers can decide how to
-- execute returned commands and interpret results.

local _cmd = require("ward.process")
local _env = require("ward.env")
local _fs = require("ward.fs")

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

---@param bin string
local function validate_bin(bin)
	assert(type(bin) == "string" and #bin > 0, "curl binary is not set")
	if bin:find("/", 1, true) then
		assert(_fs.is_exists(bin), string.format("curl binary does not exist: %s", bin))
		assert(_fs.is_executable(bin), string.format("curl binary is not executable: %s", bin))
	else
		assert(_env.is_in_path(bin), string.format("curl binary is not in PATH: %s", bin))
	end
end

---@param s any
---@param label string
local function validate_non_empty_string(s, label)
	assert(type(s) == "string" and #s > 0, label .. " must be a non-empty string")
end

---@param value string
---@param label string
local function validate_not_flag(value, label)
	validate_non_empty_string(value, label)
	assert(value:sub(1, 1) ~= "-", label .. " must not start with '-': " .. tostring(value))
end

---@param v any
---@param label string
local function validate_number(v, label)
	assert(type(v) == "number" and v >= 0, label .. " must be a non-negative number")
end

---@param args string[]
---@param opts CurlOpts|nil
local function apply_opts(args, opts)
	opts = opts or {}

	if opts.silent then
		table.insert(args, "-s")
	end
	if opts.show_error then
		table.insert(args, "-S")
	end
	if opts.verbose then
		table.insert(args, "-v")
	end
	if opts.fail then
		table.insert(args, "--fail")
	end
	if opts.location then
		table.insert(args, "-L")
	end
	if opts.head then
		table.insert(args, "-I")
	end
	if opts.insecure then
		table.insert(args, "-k")
	end
	if opts.compressed then
		table.insert(args, "--compressed")
	end
	if opts.ipv4 then
		table.insert(args, "-4")
	end
	if opts.ipv6 then
		table.insert(args, "-6")
	end
	if opts.http1_1 then
		table.insert(args, "--http1.1")
	end
	if opts.http2 then
		table.insert(args, "--http2")
	end
	if opts.remote_name then
		table.insert(args, "-O")
	end
	if opts.remote_header_name then
		table.insert(args, "-J")
	end

	if opts.request ~= nil then
		validate_not_flag(opts.request, "request")
		table.insert(args, "-X")
		table.insert(args, opts.request)
	end

	if opts.connect_timeout ~= nil then
		validate_number(opts.connect_timeout, "connect_timeout")
		table.insert(args, "--connect-timeout")
		table.insert(args, tostring(opts.connect_timeout))
	end
	if opts.max_time ~= nil then
		validate_number(opts.max_time, "max_time")
		table.insert(args, "--max-time")
		table.insert(args, tostring(opts.max_time))
	end
	if opts.retry ~= nil then
		validate_number(opts.retry, "retry")
		table.insert(args, "--retry")
		table.insert(args, tostring(opts.retry))
	end

	if opts.user_agent ~= nil then
		validate_non_empty_string(opts.user_agent, "user_agent")
		table.insert(args, "-A")
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
			validate_non_empty_string(h, "header")
			table.insert(args, "-H")
			table.insert(args, h)
		end
	end

	if opts.cookie ~= nil then
		validate_non_empty_string(opts.cookie, "cookie")
		table.insert(args, "-b")
		table.insert(args, opts.cookie)
	end
	if opts.cookie_jar ~= nil then
		validate_non_empty_string(opts.cookie_jar, "cookie_jar")
		table.insert(args, "-c")
		table.insert(args, opts.cookie_jar)
	end

	if opts.output ~= nil then
		validate_non_empty_string(opts.output, "output")
		table.insert(args, "-o")
		table.insert(args, opts.output)
	end

	if opts.data ~= nil then
		validate_non_empty_string(opts.data, "data")
		table.insert(args, "-d")
		table.insert(args, opts.data)
	end
	if opts.data_raw ~= nil then
		validate_non_empty_string(opts.data_raw, "data_raw")
		table.insert(args, "--data-raw")
		table.insert(args, opts.data_raw)
	end

	if opts.form ~= nil then
		local forms = {}
		if type(opts.form) == "string" then
			forms = { opts.form }
		elseif type(opts.form) == "table" then
			assert(#opts.form > 0, "form list must be non-empty")
			for _, f in ipairs(opts.form) do
				table.insert(forms, tostring(f))
			end
		else
			error("form must be string or string[]")
		end
		for _, f in ipairs(forms) do
			validate_non_empty_string(f, "form")
			table.insert(args, "-F")
			table.insert(args, f)
		end
	end

	if opts.cacert ~= nil then
		validate_non_empty_string(opts.cacert, "cacert")
		table.insert(args, "--cacert")
		table.insert(args, opts.cacert)
	end
	if opts.cert ~= nil then
		validate_non_empty_string(opts.cert, "cert")
		table.insert(args, "--cert")
		table.insert(args, opts.cert)
	end
	if opts.key ~= nil then
		validate_non_empty_string(opts.key, "key")
		table.insert(args, "--key")
		table.insert(args, opts.key)
	end

	if opts.write_out ~= nil then
		validate_non_empty_string(opts.write_out, "write_out")
		table.insert(args, "-w")
		table.insert(args, opts.write_out)
	end

	if opts.extra ~= nil then
		assert(type(opts.extra) == "table", "extra must be an array")
		for _, v in ipairs(opts.extra) do
			table.insert(args, tostring(v))
		end
	end
end

---Construct a curl command.
---
---If `urls` is nil, curl will run with only the configured options.
---
---@param urls string|string[]|nil
---@param opts CurlOpts|nil
---@return ward.Cmd
function Curl.request(urls, opts)
	validate_bin(Curl.bin)

	local args = { Curl.bin }
	apply_opts(args, opts)

	if urls ~= nil then
		if type(urls) == "string" then
			validate_non_empty_string(urls, "url")
			table.insert(args, urls)
		elseif type(urls) == "table" then
			assert(#urls > 0, "urls list must be non-empty")
			for _, u in ipairs(urls) do
				validate_non_empty_string(u, "url")
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
	validate_non_empty_string(url, "url")
	return Curl.request(url, opts)
end

---@param url string
---@param opts CurlOpts|nil
---@return ward.Cmd
function Curl.head(url, opts)
	validate_non_empty_string(url, "url")
	opts = opts or {}
	opts.head = true
	return Curl.request(url, opts)
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
	validate_non_empty_string(url, "url")
	opts = opts or {}
	opts.location = (opts.location ~= false) and true or false
	if out ~= nil then
		validate_non_empty_string(out, "out")
		opts.output = out
	else
		opts.remote_name = true
	end
	return Curl.request(url, opts)
end

---Convenience: POST a body.
---
---@param url string
---@param data string|nil
---@param opts CurlOpts|nil
---@return ward.Cmd
function Curl.post(url, data, opts)
	validate_non_empty_string(url, "url")
	opts = opts or {}
	opts.request = opts.request or "POST"
	if data ~= nil then
		validate_non_empty_string(data, "data")
		opts.data = data
	end
	return Curl.request(url, opts)
end

return {
	Curl = Curl,
}
