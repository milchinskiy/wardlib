-- Ward-native tiny test toolkit + multi-file runner.
local term = require("ward.term")
local time = require("ward.time")
local string_contains = require("ward.helpers.string").contains
local table_contains = require("ward.helpers.table").contains

local M = {}

local function to_s(x)
	if type(x) == "string" then return x end
	return tostring(x)
end

local function is_array(tbl)
	if type(tbl) ~= "table" then return false end
	for i = 1, #tbl do
		if tbl[i] == nil then return false end
	end
	return true
end

local function looks_like_path(s) return s:find("/", 1, true) ~= nil or s:sub(-4) == ".lua" end

-- Alias-safe deep equality (bijective visited maps)
local function deep_equal(a, b, seen_a, seen_b)
	if a == b then return true end
	if type(a) ~= type(b) then return false end
	if type(a) ~= "table" then return false end

	seen_a = seen_a or {}
	seen_b = seen_b or {}

	if seen_a[a] ~= nil or seen_b[b] ~= nil then return seen_a[a] == b and seen_b[b] == a end
	seen_a[a] = b
	seen_b[b] = a

	for k, va in pairs(a) do
		local vb = b[k]
		if vb == nil then return false end
		if not deep_equal(va, vb, seen_a, seen_b) then return false end
	end
	for k, _ in pairs(b) do
		if a[k] == nil then return false end
	end
	return true
end

local function err_obj(phase, err) return { phase = phase, message = to_s(err) } end

--- Try to get duration in seconds
---@param t0 number
---@return number?
local function try_duration(t0)
	local ok, s = pcall(function()
		local t1 = time.instant_now()
		local d = t1 - t0
		return d:seconds()
	end)
	if ok then return s end
	return nil
end

-- =========================
-- Suite
-- =========================

function M.new(opts)
	opts = opts or {}
	local t = {
		name = opts.name or "suite",
		_cases = {},
		_before_all = nil,
		_after_all = nil,
		_before_each = nil,
		_after_each = nil,
	}

	function t:test(name, fn)
		assert(type(name) == "string" and #name > 0, "test name must be non-empty string")
		assert(type(fn) == "function", "test body must be function")
		table.insert(self._cases, { name = name, fn = fn })
	end

	function t:before_all(fn)
		assert(type(fn) == "function")
		self._before_all = fn
	end
	function t:after_all(fn)
		assert(type(fn) == "function")
		self._after_all = fn
	end
	function t:before_each(fn)
		assert(type(fn) == "function")
		self._before_each = fn
	end
	function t:after_each(fn)
		assert(type(fn) == "function")
		self._after_each = fn
	end

	-- Assertions
	function t:ok(cond, msg)
		if not cond then error(msg or "assertion failed", 2) end
	end
	function t:eq(a, b, msg)
		if a ~= b then error(msg or ("expected: " .. to_s(a) .. " == " .. to_s(b)), 2) end
	end
	function t:falsy(v, msg)
		if v then error(msg or "expected falsy", 2) end
	end
	function t:truthy(v, msg)
		if not v then error(msg or "expected truthy", 2) end
	end
	function t:match(s, pat, msg)
		if type(s) ~= "string" then error(msg or "match: first argument must be string", 2) end
		if type(pat) ~= "string" then error(msg or "match: pattern must be string", 2) end
		if not string.find(s, pat) then error(msg or ("expected match: " .. pat), 2) end
	end
	function t:deep_eq(a, b, msg)
		if not deep_equal(a, b) then error(msg or "expected deep equality", 2) end
	end
	function t:contains(a, b)
		if type(a) == "string" then
			return string_contains(a, b)
		elseif type(a) == "table" then
			return table_contains(a, b)
		else
			error("contains: first argument must be string or table", 2)
		end
	end

	local function safe_call(phase, fn)
		if not fn then return true end
		local ok, err = pcall(fn)
		if ok then return true end
		return false, err_obj(phase, err)
	end

	function t:list()
		local out = {}
		for _, c in ipairs(self._cases) do
			out[#out + 1] = c.name
		end
		return out
	end

	function t:run(opts2)
		opts2 = opts2 or {}
		local reporter = opts2.reporter
		local filter = opts2.filter
		local fail_fast = opts2.fail_fast == true

		local planned = #self._cases
		local res = {
			suite = self.name,
			planned = planned,
			started_at = time.now(),
			finished_at = nil,

			total = 0,
			passed = 0,
			failed = 0,
			skipped = 0,

			tests = {},
			failures = {},

			bailed = false,
			bail_error = nil,
		}

		local function emit(ev)
			if reporter then reporter(ev) end
		end

		emit({ kind = "suite_start", suite = self.name, planned = planned })

		do
			local ok, e = safe_call("before_all", self._before_all)
			if not ok then
				res.bailed = true
				res.bail_error = e
				emit({ kind = "suite_bail", suite = self.name, error = e })
				res.finished_at = time.now()
				emit({
					kind = "suite_end",
					suite = self.name,
					total = 0,
					passed = 0,
					failed = 1,
					skipped = 0,
					bailed = true,
				})
				return res
			end
		end

		for _, case in ipairs(self._cases) do
			if filter and not filter(case.name) then
				res.skipped = res.skipped + 1
				res.tests[#res.tests + 1] = { name = case.name, ok = true, skipped = true, duration = nil }
				emit({
					kind = "test_end",
					suite = self.name,
					name = case.name,
					ok = true,
					skipped = true,
					duration = nil,
				})
			else
				res.total = res.total + 1
				local t0 = time.instant_now()
				emit({ kind = "test_start", suite = self.name, name = case.name })

				local ok_before, e_before = safe_call("before_each", self._before_each)

				local ok_test, e_test = true, nil
				if ok_before then
					local ok, err = pcall(case.fn)
					if not ok then
						ok_test = false
						e_test = err_obj("test", err)
					end
				else
					ok_test = false
					e_test = e_before
				end

				local ok_after, e_after = safe_call("after_each", self._after_each)
				if not ok_after then
					ok_test = false
					if e_test and e_after then
						e_test =
							{ phase = e_test.phase, message = e_test.message .. "\n(after_each) " .. e_after.message }
					else
						e_test = e_after
					end
				end

				local dur = try_duration(t0)

				if ok_test then
					res.passed = res.passed + 1
					res.tests[#res.tests + 1] = { name = case.name, ok = true, skipped = false, duration = dur }
					emit({
						kind = "test_end",
						suite = self.name,
						name = case.name,
						ok = true,
						skipped = false,
						duration = dur,
					})
				else
					res.failed = res.failed + 1
					local entry = { name = case.name, ok = false, skipped = false, duration = dur, error = e_test }
					res.tests[#res.tests + 1] = entry
					res.failures[#res.failures + 1] = { name = case.name, error = e_test }
					emit({
						kind = "test_end",
						suite = self.name,
						name = case.name,
						ok = false,
						skipped = false,
						duration = dur,
						error = e_test,
					})
					if fail_fast then break end
				end
			end
		end

		do
			local ok, e = safe_call("after_all", self._after_all)
			if not ok then
				res.failed = res.failed + 1
				res.failures[#res.failures + 1] = { name = "<after_all>", error = e }
				res.tests[#res.tests + 1] =
					{ name = "<after_all>", ok = false, skipped = false, duration = nil, error = e }
				emit({ kind = "suite_error", suite = self.name, error = e })
			end
		end

		res.finished_at = time.now()
		emit({
			kind = "suite_end",
			suite = self.name,
			total = res.total,
			passed = res.passed,
			failed = res.failed,
			skipped = res.skipped,
			bailed = res.bailed,
		})
		return res
	end

	return t
end

-- =========================
-- Load suite
-- =========================

local function load_suite(spec)
	local ok, ret

	if looks_like_path(spec) then
		local chunk, err = loadfile(spec)
		if not chunk then return nil, err_obj("load", "loadfile failed: " .. to_s(err)) end
		ok, ret = pcall(chunk)
	else
		ok, ret = pcall(require, spec)
	end

	if not ok then return nil, err_obj("load", ret) end

	if type(ret) == "function" then
		local ok2, v = pcall(ret, M)
		if not ok2 then return nil, err_obj("load", v) end
		ret = v
	end

	if type(ret) ~= "table" or type(ret.run) ~= "function" then
		return nil, err_obj("load", "test file must return a tinytest suite (tinytest.new(...))")
	end

	return ret, nil
end

-- =========================
-- Console reporter (single-string printing)
-- =========================

local function reporter_console()
	return function(ev)
		if ev.kind == "suite_start" then
			term.println(
				string.format("%s== RUN %s (planned %d) ==%s", term.ansi.bold, ev.suite, ev.planned, term.ansi.reset)
			)
		elseif ev.kind == "test_end" then
			local duration = ""
			if ev.duration then
				duration =
					string.format("%s%-10s%s", term.ansi.yellow, string.format("%.5fs", ev.duration), term.ansi.reset)
			end

			if ev.skipped then
				term.println("SKIP", ev.name)
			elseif ev.ok then
				local str = string.format(
					" %s✔ OK%s\t%s\t%s%s%s",
					term.ansi.green,
					term.ansi.reset,
					duration,
					term.ansi.bold,
					ev.name,
					term.ansi.reset
				)
				term.println(str)
			else
				local str = string.format(
					" %s✘ FAIL%s\t%s\t%s%s%s",
					term.ansi.red,
					term.ansi.reset,
					duration,
					term.ansi.bold,
					ev.name,
					term.ansi.reset
				)
				term.eprintln(str)
				if ev.error then
					term.eprintln("\tphase:", ev.error.phase)
					term.eprintln("\tmsg:", ev.error.message)
				end
			end
		elseif ev.kind == "suite_bail" then
			term.eprintln("BAIL ", ev.suite)
			if ev.error then
				term.eprintln("\tphase:", ev.error.phase)
				term.eprintln("\tmsg:", ev.error.message)
			end
		elseif ev.kind == "suite_end" then
			term.println("")
		end
	end
end

-- =========================
-- Multi-suite runner
-- =========================

function M.run(specs, opts)
	opts = opts or {}
	assert(type(specs) == "table" and is_array(specs) and #specs > 0, "run: specs must be array of file/module strings")

	local only = opts.only
	local function filter(name)
		if not only or only == "" then return true end
		return name:find(only, 1, true) ~= nil
	end

	local rep = reporter_console()
	local all = { total = 0, passed = 0, failed = 0, skipped = 0, suites = {} }

	for _, spec in ipairs(specs) do
		local suite, load_err = load_suite(spec)
		if not suite and load_err then
			all.failed = all.failed + 1
			all.suites[#all.suites + 1] = { spec = spec, load_error = load_err }
			term.eprintln("FAILED to load:", spec)
			term.eprintln("  ", load_err.message)
		elseif suite then
			local r = suite:run({ reporter = rep, filter = filter, fail_fast = opts.fail_fast == true })
			all.total = all.total + r.total
			all.passed = all.passed + r.passed
			all.failed = all.failed + r.failed
			all.skipped = all.skipped + r.skipped
			all.suites[#all.suites + 1] = { spec = spec, result = r }

			if r.failed > 0 then
				local str = string.format("Failures in %s%s%s:", term.ansi.bold, suite.name, term.ansi.reset)
				term.eprintln(str)
				for _, f in ipairs(r.failures) do
					local what = string.format(
						" -\t%s%s%s\t[%s%s%s]",
						term.ansi.bright_white,
						f.name,
						term.ansi.reset,
						term.ansi.yellow,
						f.error.phase,
						term.ansi.reset
					)
					term.eprintln(what)

					local err = string.format("\t%s%s%s", term.ansi.red, f.error.message, term.ansi.reset)
					term.eprintln(err)
				end
			end
		end
	end

	term.println(string.format("TOTAL:\t%d", all.total))

	if all.passed > 0 then
		term.println(
			string.format(
				"%s%s%sPASS:\t%d%s",
				term.ansi.underline,
				term.ansi.green,
				term.ansi.bold,
				all.passed,
				term.ansi.reset
			)
		)
	end

	if all.failed > 0 then term.println(string.format("%sFAIL:\t%d%s", term.ansi.red, all.failed, term.ansi.reset)) end

	if all.skipped > 0 then
		term.println(string.format("%sSKIP:\t%d%s", term.ansi.bright_black, all.skipped, term.ansi.reset))
	end

	return all
end

return M