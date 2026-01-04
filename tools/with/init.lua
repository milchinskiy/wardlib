--- wardlib.tools.with
---
--- Helpers for scoped (temporary) Ward process middleware.
---
--- Motivation
---
--- Ward exposes `ward.process.push_middleware(fn)` / `pop_middleware()` to let you
--- modify command spawn specs right before execution (e.g. prefix argv with sudo).
---
--- This module provides:
---   * `with(mw, fn, ...)`        - run `fn(...)` with middleware `mw` installed
---   * `with(prefix, cmd)`        - wrap a cmd-like object so its methods execute under prefix
---   * `middleware.prefix(...)`   - build a prefixing middleware
---   * `middleware.sudo(...)`     - common helpers
---   * `middleware.doas(...)`
---
--- Usage
---
--- ```lua
--- local process = require("ward.process")
--- local w = require("tools.with")
---
--- -- 1) Scope a middleware around any block:
--- w.with(w.middleware.sudo(), function()
---   process.cmd("ls", "-la"):run()
--- end)
---
--- -- 2) Wrap a cmd-like object so any method call happens under sudo:
--- local ls = w.with(process.cmd("sudo"), process.cmd("ls", "-la"))
--- ls:run()
---
--- -- 3) Or be explicit with argv prefix:
--- local ls2 = w.with({"sudo", "-n"}, process.cmd("ls", "-la"))
--- ls2:run()
--- ```
---
--- Notes
---
--- * This module uses best-effort extraction of argv from a "prefix cmd" object
---   (tries `.argv`, `.spec.argv`, `._spec.argv`). If that doesn't match your
---   local Ward build, pass prefix argv as an array instead.
---
local process = require("ward.process")

local M = {}

local function _is_array(t)
	return type(t) == "table" and t[1] ~= nil
end

local function _clone_array(t)
	local out = {}
	for i = 1, #t do
		out[i] = t[i]
	end
	return out
end

--- Best-effort extraction of argv from a Ward cmd object or argv array.
---
--- Supported:
---   * "sudo"                         -> {"sudo"}
---   * {"sudo", "-n"}                 -> {"sudo", "-n"}
---   * { argv = {"sudo"} }            -> {"sudo"}
---   * { spec = { argv = {"sudo"} } } -> {"sudo"}
---   * { _spec = { argv = {"sudo"} } }-> {"sudo"}
---
local function _as_argv(prefix)
	if type(prefix) == "string" then
		return { prefix }
	end

	if _is_array(prefix) then
		return _clone_array(prefix)
	end

	if type(prefix) == "table" then
		if type(prefix.argv) == "table" and _is_array(prefix.argv) then
			return _clone_array(prefix.argv)
		end
		if type(prefix.spec) == "table" and type(prefix.spec.argv) == "table" and _is_array(prefix.spec.argv) then
			return _clone_array(prefix.spec.argv)
		end
		if type(prefix._spec) == "table" and type(prefix._spec.argv) == "table" and _is_array(prefix._spec.argv) then
			return _clone_array(prefix._spec.argv)
		end
	end

	error("tools.with: unsupported prefix (expected string|argv[]|cmd-like with argv)")
end

--- Run a function with middleware installed.
---
--- @param mw function(spec): spec|nil
--- @param fn function(...)
--- @return ... returns fn(...) results
function M.scope(mw, fn, ...)
	process.push_middleware(mw)
	local ok, r1, r2, r3, r4, r5, r6 = pcall(fn, ...)
	process.pop_middleware()
	if ok then
		return r1, r2, r3, r4, r5, r6
	end
	error(r1, 0)
end

--- Middleware constructors.
M.middleware = {}

--- Prefix argv middleware.
---
--- @param prefix string|table cmd-like or argv array
--- @param opts table|nil
---   * sep (string|nil)        optional separator inserted between prefix and argv (e.g. "--")
---   * field (string|nil)      which field to mutate: "argv" (default) or "args"
---
--- @return function(spec): spec
function M.middleware.prefix(prefix, opts)
	opts = opts or {}
	local p = _as_argv(prefix)
	local sep = opts.sep
	local field = opts.field or "argv"

	return function(spec)
		if type(spec) ~= "table" then
			return spec
		end

		local argv = spec[field]
		if type(argv) ~= "table" or not _is_array(argv) then
			return spec
		end

		local out = {}
		for i = 1, #p do
			out[#out + 1] = p[i]
		end
		if sep ~= nil then
			out[#out + 1] = sep
		end
		for i = 1, #argv do
			out[#out + 1] = argv[i]
		end

		spec[field] = out
		return spec
	end
end

--- Convenience: sudo middleware.
---
--- @param opts table|nil
---   * non_interactive (boolean|nil) default true => adds "-n"
---   * preserve_env (boolean|nil)   adds "-E"
---   * sep (string|nil)             passed to prefix middleware
---
function M.middleware.sudo(opts)
	opts = opts or {}
	local argv = { "sudo" }

	if opts.non_interactive ~= false then
		argv[#argv + 1] = "-n"
	end
	if opts.preserve_env then
		argv[#argv + 1] = "-E"
	end

	return M.middleware.prefix(argv, { sep = opts.sep, field = opts.field })
end

--- Convenience: doas middleware.
---
--- @param opts table|nil
---   * non_interactive (boolean|nil) default true => adds "-n" (OpenBSD doas)
---   * keep_env (boolean|nil)        adds "-E" (implementation dependent)
---   * sep (string|nil)              passed to prefix middleware
---
function M.middleware.doas(opts)
	opts = opts or {}
	local argv = { "doas" }

	if opts.non_interactive ~= false then
		argv[#argv + 1] = "-n"
	end
	if opts.keep_env then
		argv[#argv + 1] = "-E"
	end

	return M.middleware.prefix(argv, { sep = opts.sep, field = opts.field })
end

--- Wrap a cmd-like object so method calls execute with a middleware installed.
---
--- This is intentionally "duck-typed": anything table-like with function fields
--- (e.g. :run(), :output(), :spawn(), :status(), etc.) will work.
---
--- @param mw_or_prefix function|table|string
--- @param cmd any table-like object
--- @param opts table|nil options for prefix middleware (only used if mw_or_prefix is not a function)
--- @return proxy table
function M.wrap(mw_or_prefix, cmd, opts)
	local mw
	if type(mw_or_prefix) == "function" then
		mw = mw_or_prefix
	else
		mw = M.middleware.prefix(mw_or_prefix, opts)
	end

	local proxy = {}

	return setmetatable(proxy, {
		__index = function(_, k)
			local v = cmd[k]
			if type(v) == "function" then
				return function(_, ...)
					-- Execute the underlying method under scope.
					return M.scope(mw, v, cmd, ...)
				end
			end
			return v
		end,

		__call = function(_, ...)
			-- If cmd is callable, call it under scope.
			if type(cmd) ~= "function" then
				error("tools.with: wrapped value is not callable")
			end
			return M.scope(mw, cmd, ...)
		end,
	})
end

--- High-level helper.
---
--- Overloads:
---   * with(mw, fn, ...)                 -> scope
---   * with(prefix, fn, ...)             -> scope with prefix middleware
---   * with(mw_or_prefix, cmd[, opts])   -> proxy wrapper
---
function M.with(mw_or_prefix, a, ...)
	if type(a) == "function" then
		local mw
		if type(mw_or_prefix) == "function" then
			mw = mw_or_prefix
		else
			mw = M.middleware.prefix(mw_or_prefix)
		end
		return M.scope(mw, a, ...)
	end

	-- cmd-like wrapper
	return M.wrap(mw_or_prefix, a, ...)
end

-- Expose internals for tests.
M._as_argv = _as_argv
M._clone_array = _clone_array
M._is_array = _is_array

return M
