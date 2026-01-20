-- wardlib.tools.out
--
-- Fluent, predictable parsing for ward.process.Cmd output.
--
-- Design goals:
--   * Native Ward workflow: cmd -> :output() -> parse stdout/stderr.
--   * Fail-fast with high quality error messages (label + exit status + bounded preview).
--   * Small surface area: chainable configuration + terminal extractors.
--
-- Example:
--   local p = require("ward.process")
--   local out = require("wardlib.tools.out")
--
--   local sha = out.cmd(p.cmd("git", "rev-parse", "HEAD"))
--     :label("git rev-parse HEAD")
--     :trim()
--     :line()

local validate = require("wardlib.util.validate")

local M = {}

local function ltrim(s) return (s:gsub("^%s+", "")) end
local function rtrim(s) return (s:gsub("%s+$", "")) end

local function normalize_newlines(s)
	-- Convert CRLF and CR to LF.
	return (s:gsub("\r\n", "\n"):gsub("\r", "\n"))
end

local function preview_bytes(s, max_bytes)
	if s == nil then return "<nil>" end
	max_bytes = max_bytes or 2048
	if #s <= max_bytes then return string.format("%d bytes:\n%s", #s, s) end
	return string.format(
		"%d bytes (showing first %d bytes):\n%s\n...<truncated>",
		#s,
		max_bytes,
		s:sub(1, max_bytes)
	)
end

local function fmt_status(res)
	local code = res and res.code
	local sig = res and res.signal
	return string.format("code=%s, signal=%s", tostring(code), tostring(sig))
end

local Out = {}
Out.__index = Out

local pack = table.pack
if pack == nil then
	pack = function(...)
		local t = { ... }
		t.n = select("#", ...)
		return t
	end
end

local function is_cmd(x) return type(x) == "table" and type(x.output) == "function" end
local function is_res(x) return type(x) == "table" and (x.ok ~= nil or x.stdout ~= nil or x.stderr ~= nil) end

local function new_from_cmd(cmd)
	if not is_cmd(cmd) then error("tools.out.cmd: expected ward.process cmd object (missing :output())", 3) end
	return setmetatable({
		_cmd = cmd,
		_res = nil,
		_label = nil,
		_stream = "stdout",
		_require_ok = true,
		_trim_mode = nil, -- 'trim'|'ltrim'|'rtrim'
		_normalize_newlines = true,
		_max_preview = 2048,
	}, Out)
end

local function new_from_res(res)
	if not is_res(res) then error("tools.out.res: expected CmdResult-like table", 3) end
	return setmetatable({
		_cmd = nil,
		_res = res,
		_label = nil,
		_stream = "stdout",
		_require_ok = true,
		_trim_mode = nil,
		_normalize_newlines = true,
		_max_preview = 2048,
	}, Out)
end

-- Constructors
function M.cmd(cmd) return new_from_cmd(cmd) end
function M.res(res) return new_from_res(res) end

-- --- chainable configuration ---

function Out:label(s)
	validate.non_empty_string(s, "label")
	self._label = s
	return self
end

function Out:stdout()
	self._stream = "stdout"
	return self
end

function Out:stderr()
	self._stream = "stderr"
	return self
end

function Out:ok()
	self._require_ok = true
	return self
end

function Out:allow_fail()
	self._require_ok = false
	return self
end

function Out:trim()
	self._trim_mode = "trim"
	return self
end

function Out:ltrim()
	self._trim_mode = "ltrim"
	return self
end

function Out:rtrim()
	self._trim_mode = "rtrim"
	return self
end

function Out:normalize_newlines(v)
	if v == nil then
		self._normalize_newlines = true
	else
		self._normalize_newlines = v == true
	end
	return self
end

function Out:max_preview(n)
	validate.integer_min(n, "max_preview", 0)
	self._max_preview = n
	return self
end

-- --- internals ---

function Out:_ensure_res()
	if self._res ~= nil then return self._res end
	local res = self._cmd:output()
	self._res = res
	return res
end

function Out:_error_prefix()
	return self._label or (self._stream .. " output")
end

function Out:_assert_ok(res)
	if not self._require_ok then return end
	if res.ok == true then return end

	local prefix = self:_error_prefix()
	local stderr = res.stderr
	local stdout = res.stdout
	local best = (stderr ~= nil and #stderr > 0) and stderr or stdout
	local best_name = (stderr ~= nil and #stderr > 0) and "stderr" or "stdout"
	local msg = string.format(
		"%s failed (%s)\n%s preview:\n%s",
		prefix,
		fmt_status(res),
		best_name,
		preview_bytes(best, self._max_preview)
	)
	error(msg, 3)
end

function Out:_get_text()
	local res = self:_ensure_res()
	self:_assert_ok(res)

	local s = (self._stream == "stderr") and res.stderr or res.stdout
	if s == nil then
		local prefix = self:_error_prefix()
		error(prefix .. ": " .. self._stream .. " is nil; use :output() to capture output", 3)
	end

	if self._normalize_newlines then s = normalize_newlines(s) end

	if self._trim_mode == "trim" then
		local str = require("ward.helpers.string")
		s = str.trim(s)
	elseif self._trim_mode == "ltrim" then
		s = ltrim(s)
	elseif self._trim_mode == "rtrim" then
		s = rtrim(s)
	end

	return s
end

-- --- terminal extractors ---

function Out:text() return self:_get_text() end

function Out:lines()
	local s = self:_get_text()
	if s == "" then return {} end

	-- If output ends with newline, ignore the final empty segment.
	local ends_nl = s:sub(-1) == "\n"
	local out = {}
	for line in (s .. "\n"):gmatch("(.-)\n") do
		out[#out + 1] = line
	end
	if ends_nl and #out > 0 and out[#out] == "" then out[#out] = nil end
	return out
end

function Out:line()
	local ls = self:lines()
	if #ls == 1 then return ls[1] end
	local prefix = self:_error_prefix()
	if #ls == 0 then error(prefix .. ": expected one line, got empty output", 3) end
	error(prefix .. ": expected one line, got " .. tostring(#ls) .. " lines", 3)
end

function Out:match(pat)
	validate.non_empty_string(pat, "pattern")
	local s = self:_get_text()
	local a = s:match(pat)
	if a == nil then
		local prefix = self:_error_prefix()
		error(prefix .. ": no match for pattern: " .. pat, 3)
	end
	-- Return captures natively (multiple returns when pattern has captures).
	return s:match(pat)
end

function Out:matches(pat)
	validate.non_empty_string(pat, "pattern")
	local s = self:_get_text()
	local out = {}
	local it = s:gmatch(pat)
	while true do
		local p = pack(it())
		if p.n == 0 or p[1] == nil then break end
		if p.n <= 1 then
			out[#out + 1] = p[1]
		else
			local t = {}
			for i = 1, p.n do
				t[i] = p[i]
			end
			out[#out + 1] = t
		end
	end
	return out
end

local function decode(self, format, mod_name, fn_name)
	local s = self:_get_text()
	local ok, mod = pcall(require, mod_name)
	if not ok then error("tools.out: missing decoder module: " .. mod_name, 3) end
	local dec = mod[fn_name]
	if type(dec) ~= "function" then error("tools.out: decoder missing: " .. mod_name .. "." .. fn_name, 3) end

	local ok2, v = pcall(dec, s)
	if ok2 then return v end

	local prefix = self:_error_prefix()
	local msg = string.format(
		"%s: failed to decode %s: %s\n%s preview:\n%s",
		prefix,
		format,
		tostring(v),
		self._stream,
		preview_bytes(s, self._max_preview)
	)
	error(msg, 3)
end

function Out:json() return decode(self, "json", "ward.convert.json", "decode") end
function Out:yaml() return decode(self, "yaml", "ward.convert.yaml", "decode") end
function Out:toml() return decode(self, "toml", "ward.convert.toml", "decode") end
function Out:ini() return decode(self, "ini", "ward.convert.ini", "decode") end

-- Decode newline-delimited JSON (NDJSON/JSON Lines).
-- Commonly used by tools like: journalctl -o json
function Out:json_lines()
	local ls = self:lines()
	local ok, mod = pcall(require, "ward.convert.json")
	if not ok then error("tools.out: missing decoder module: ward.convert.json", 3) end
	local dec = mod.decode
	if type(dec) ~= "function" then error("tools.out: decoder missing: ward.convert.json.decode", 3) end

	local out = {}
	local prefix = self:_error_prefix()
	for i = 1, #ls do
		local line = ls[i]
		if line ~= "" then
			local ok2, v = pcall(dec, line)
			if not ok2 then
				local msg = string.format(
					"%s: failed to decode json line %d: %s\n%s line preview:\n%s",
					prefix,
					i,
					tostring(v),
					self._stream,
					preview_bytes(line, self._max_preview)
				)
				error(msg, 3)
			end
			out[#out + 1] = v
		end
	end
	return out
end

return M
