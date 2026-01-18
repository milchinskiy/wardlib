-- wardlib.tools.retry
--
-- A small, wardlib-facing wrapper around Ward core `ward.helpers.retry`.
--
-- Ward provides a retry loop in `ward.helpers.retry.run(fn, opts)`.
-- This module adds:
--   * option aliases (`tries`)
--   * `should_retry(err)` hook to stop retries early
--   * `pcall` helper returning (ok, value_or_err)

local validate = require("wardlib.util.validate")

local M = {}

local ABORT = {}

local function clean_error_message(e)
	local s = tostring(e)
	-- Strip leading "file:line: " prefixes introduced by Lua's `error()` formatting.
	-- Do it repeatedly to handle nested wrapping.
	while true do
		local stripped = s:gsub("^.-:%d+:%s*", "", 1)
		if stripped == s then break end
		s = stripped
	end
	return s
end

local function core_retry()
	local ok, mod = pcall(require, "ward.helpers.retry")
	if not ok then error("tools.retry: ward.helpers.retry is not available in this Ward build", 2) end
	return mod
end

local function normalize_opts(opts)
	opts = opts or {}
	assert(type(opts) == "table", "retry options must be a table")

	local out = {}

	local tries = opts.tries
	local attempts = opts.attempts
	if tries ~= nil and attempts ~= nil then
		error("tools.retry: only one of 'tries' or 'attempts' may be specified", 2)
	end
	if tries ~= nil then
		validate.integer_non_negative(tries, "tries")
		out.attempts = math.max(1, tries)
	elseif attempts ~= nil then
		validate.integer_non_negative(attempts, "attempts")
		out.attempts = math.max(1, attempts)
	end

	local delay = opts.delay
	if delay ~= nil then
		-- Ward core accepts duration strings ("100ms") or numbers.
		out.delay = delay
	end

	if opts.max_delay ~= nil then
		out.max_delay = opts.max_delay
	elseif opts.max ~= nil then
		out.max_delay = opts.max
	end

	if opts.backoff ~= nil then out.backoff = opts.backoff end
	if opts.jitter ~= nil then out.jitter = opts.jitter end
	if opts.jitter_ratio ~= nil then out.jitter_ratio = opts.jitter_ratio end

	return out
end

--- Retry `fn()` according to policy.
---
--- This is a thin wrapper around `ward.helpers.retry.run`.
---
--- @param fn function
--- @param opts table|nil
--- @return any
function M.call(fn, opts)
	assert(type(fn) == "function", "retry.call: fn must be a function")
	opts = opts or {}
	assert(type(opts) == "table", "retry.call: opts must be a table")

	local should_retry = opts.should_retry
	if should_retry ~= nil then
		assert(type(should_retry) == "function", "retry.call: should_retry must be a function")
	end

	local core = core_retry()
	local core_opts = normalize_opts(opts)

	-- If should_retry says "do not retry", return a sentinel value instead of
	-- raising an error. This causes ward.helpers.retry.run(...) to stop.
	local function wrapped()
		local ok, v = pcall(fn)
		if ok then return v end

		local raw_err = v
		local msg = clean_error_message(raw_err)

		-- Pass a clean message to should_retry for ergonomics, but preserve the
		-- original error (including source location) for propagation.
		if should_retry and not should_retry(msg, raw_err) then return { __kind = ABORT, err = raw_err } end

		error(raw_err, 0)
	end

	local v = core.run(wrapped, core_opts)
	if type(v) == "table" and v.__kind == ABORT then
		-- Preserve the original error value (without file:line prefixes)
		error(v.err, 0)
	end

	return v
end

--- Like `call`, but returns (ok, value_or_err).
---
--- @param fn function
--- @param opts table|nil
--- @return boolean, any
function M.pcall(fn, opts)
	local ok, v = pcall(M.call, fn, opts)
	return ok, v
end

return M
