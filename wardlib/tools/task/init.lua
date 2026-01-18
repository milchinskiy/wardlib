--- wardlib.tools.task
---
--- Minimal task runner / orchestrator for Ward scripts.
---
--- Goals:
---   * Deterministic task ordering (definition order + explicit deps order).
---   * Dependency resolution with cycle detection.
---   * Conditional execution (`when`).
---   * Structured results suitable for CI/logging.
---   * No implicit process exit and no implicit printing.
---
--- Non-goals (at least for now):
---   * Parallel execution.
---   * Persistent state storage.
---   * Global magic integration with tools.cli.
---
--- A task is defined as:
---   name (string) + fn(ctx, run) + optional meta { deps, desc, when }.
---
--- Task function return conventions:
---   * nil / true         => ok
---   * { status = "ok" }  => ok
---   * { status = "skip", reason = "..." } => skipped
---   * { status = "error", error = "..." } => treated as failure
---   * any other value     => ok (captured in `value`)
---
--- When a task errors (throws), the runner records the failure and (optionally)
--- stops early when `fail_fast=true`.
---
--- Events (optional):
---   The runner accepts `opts.on_event(ev)` and emits:
---     { kind="runner_start", requested={...}, plan={...} }
---     { kind="task_start", name=..., index=i, total=n }
---     { kind="task_end", name=..., status=..., duration=..., result=... }
---     { kind="runner_end", ok=..., failed=n, skipped=n, results=... }
---
local M = {}

local function is_array(t) return type(t) == "table" and t[1] ~= nil end

local function shallow_copy(t)
	if t == nil then return {} end
	local out = {}
	for k, v in pairs(t) do
		out[k] = v
	end
	return out
end

local function to_s(x)
	if type(x) == "string" then return x end
	return tostring(x)
end

local function err_obj(code, message, extra)
	local e = { code = code, message = message }
	if type(extra) == "table" then
		for k, v in pairs(extra) do
			e[k] = v
		end
	end
	return e
end

local function try_instant_now()
	local ok, time = pcall(require, "ward.time")
	if not ok or type(time) ~= "table" then return nil end
	if type(time.instant_now) ~= "function" then return nil end
	local ok2, inst = pcall(time.instant_now)
	if not ok2 then return nil end
	return inst
end

local function try_duration_secs(t0)
	if t0 == nil then return nil end
	local ok, time = pcall(require, "ward.time")
	if not ok or type(time) ~= "table" then return nil end
	if type(time.instant_now) ~= "function" then return nil end
	local ok2, t1 = pcall(time.instant_now)
	if not ok2 or t1 == nil then return nil end
	local ok3, d = pcall(function()
		local delta = t1 - t0
		return delta:seconds()
	end)
	if ok3 then return d end
	return nil
end

local function normalize_requested(name_or_names, default)
	if name_or_names == nil then
		if default == nil then return {} end
		return { default }
	end
	if type(name_or_names) == "string" then return { name_or_names } end
	assert(type(name_or_names) == "table" and is_array(name_or_names), "task names must be string or string[]")
	return name_or_names
end

local function normalize_meta(meta)
	meta = meta or {}
	assert(type(meta) == "table", "task meta must be table")
	if meta.deps ~= nil then
		assert(type(meta.deps) == "table" and is_array(meta.deps), "task meta.deps must be string[]")
		for _, d in ipairs(meta.deps) do
			assert(type(d) == "string" and d ~= "", "task meta.deps must contain non-empty strings")
		end
	end
	if meta.desc ~= nil then assert(type(meta.desc) == "string", "task meta.desc must be string") end
	if meta.when ~= nil then assert(type(meta.when) == "function", "task meta.when must be function") end
	return meta
end

local Runner = {}
Runner.__index = Runner

--- Create a runner.
--- @param opts table|nil
---   * default (string|nil) default task name
---   * on_event (function|nil) event callback
--- @return table
function M.runner(opts)
	opts = opts or {}
	assert(type(opts) == "table", "opts must be table")

	local self = setmetatable({
		_default = opts.default,
		_on_event = opts.on_event,
		_tasks = {},
		_order = {},
		_seq = 0,
	}, Runner)

	return self
end

--- Define a task.
--- @param name string
--- @param fn function(ctx, run): any
--- @param meta table|nil { deps=string[], desc=string, when=function }
function Runner:define(name, fn, meta)
	assert(type(name) == "string" and name ~= "", "task name must be non-empty string")
	assert(type(fn) == "function", "task body must be function")
	if self._tasks[name] ~= nil then error("task already defined: " .. name, 2) end

	meta = normalize_meta(meta)
	self._seq = self._seq + 1
	local t = { name = name, fn = fn, meta = meta, idx = self._seq }
	self._tasks[name] = t
	self._order[#self._order + 1] = name
	return self
end

--- Get a task definition (or nil).
function Runner:get(name) return self._tasks[name] end

--- List tasks in definition order.
--- @return table[] array of { name, desc, deps }
function Runner:list()
	local out = {}
	for _, name in ipairs(self._order) do
		local t = self._tasks[name]
		out[#out + 1] = {
			name = name,
			desc = t.meta and t.meta.desc or nil,
			deps = (t.meta and t.meta.deps) and shallow_copy(t.meta.deps) or {},
		}
	end
	return out
end

local function build_cycle_path(stack, name)
	local out = {}
	local started = false
	for _, n in ipairs(stack) do
		if n == name then started = true end
		if started then out[#out + 1] = n end
	end
	out[#out + 1] = name
	return table.concat(out, " -> ")
end

--- Plan execution order.
--- @param name_or_names string|string[]|nil
--- @return boolean ok, table plan_or_err
function Runner:plan(name_or_names)
	local requested = normalize_requested(name_or_names, self._default)
	if #requested == 0 then return true, {} end

	for _, n in ipairs(requested) do
		if self._tasks[n] == nil then return false, err_obj("unknown_task", "unknown task: " .. n, { name = n }) end
	end

	local visiting = {}
	local visited = {}
	local stack = {}
	local plan = {}

	local function dfs(name)
		if visited[name] then return true end
		if visiting[name] then
			return false,
				err_obj("cycle", "dependency cycle detected: " .. build_cycle_path(stack, name), {
					name = name,
				})
		end

		visiting[name] = true
		stack[#stack + 1] = name

		local t = self._tasks[name]
		local deps = (t.meta and t.meta.deps) or {}
		for _, d in ipairs(deps) do
			if self._tasks[d] == nil then
				return false,
					err_obj("unknown_dep", "unknown dependency: " .. d .. " (required by " .. name .. ")", {
						name = name,
						dep = d,
					})
			end
			local ok, e = dfs(d)
			if not ok then return false, e end
		end

		stack[#stack] = nil
		visiting[name] = nil
		visited[name] = true
		plan[#plan + 1] = name
		return true
	end

	for _, n in ipairs(requested) do
		local ok, e = dfs(n)
		if not ok then return false, e or err_obj("unknown_error", "unknown error") end
	end

	return true, plan
end

local function normalize_task_result(ret)
	if ret == nil or ret == true then return { status = "ok" } end
	if type(ret) == "table" and type(ret.status) == "string" then
		local r = shallow_copy(ret)
		if r.status ~= "ok" and r.status ~= "skip" and r.status ~= "error" then r.status = "ok" end
		return r
	end
	return { status = "ok", value = ret }
end

local function safe_when(fn, ctx, run)
	if fn == nil then return true end
	local ok, v = pcall(fn, ctx, run)
	if not ok then return false, err_obj("when_error", "task when() failed: " .. to_s(v)) end
	return not not v
end

--- Run one or more tasks.
--- @param name_or_names string|string[]|nil default to runner default
--- @param ctx table|nil user context
--- @param opts table|nil
---   * dry_run (boolean|nil)
---   * fail_fast (boolean|nil)
---   * on_event (function|nil) overrides runner on_event
--- @return boolean ok, table report_or_err
function Runner:run(name_or_names, ctx, opts)
	opts = opts or {}
	assert(type(opts) == "table", "opts must be table")
	ctx = ctx or {}
	assert(type(ctx) == "table", "ctx must be table")

	local requested = normalize_requested(name_or_names, self._default)
	local ok_plan, plan_or_err = self:plan(requested)
	if not ok_plan then return false, plan_or_err end

	local plan = plan_or_err
	local on_event = opts.on_event or self._on_event
	local function emit(ev)
		if on_event then on_event(ev) end
	end

	local run = {
		requested = shallow_copy(requested),
		plan = shallow_copy(plan),
		results = {},
		total = #plan,
		passed = 0,
		skipped = 0,
		failed = 0,
		ok = true,
	}

	emit({ kind = "runner_start", requested = run.requested, plan = run.plan })

	for i, name in ipairs(plan) do
		local t = self._tasks[name]
		emit({ kind = "task_start", name = name, index = i, total = #plan })

		local entry = { name = name, status = "ok", reason = nil, error = nil, duration = nil, result = nil }
		local t0 = try_instant_now()

		-- dry-run skip
		if opts.dry_run then
			entry.status = "skip"
			entry.reason = "dry_run"
		else
			-- when predicate
			local can_run, when_err = safe_when(t.meta and t.meta.when, ctx, run)
			if when_err ~= nil then
				entry.status = "error"
				entry.error = when_err.message
			else
				if not can_run then
					entry.status = "skip"
					entry.reason = "when_false"
				else
					local ok_call, ret = pcall(t.fn, ctx, run)
					if not ok_call then
						entry.status = "error"
						entry.error = to_s(ret)
					else
						local normalized = normalize_task_result(ret)
						entry.status = normalized.status
						entry.reason = normalized.reason
						entry.error = normalized.error
						entry.result = normalized
					end
				end
			end
		end

		entry.duration = try_duration_secs(t0)
		run.results[#run.results + 1] = entry

		if entry.status == "ok" then
			run.passed = run.passed + 1
		elseif entry.status == "skip" then
			run.skipped = run.skipped + 1
		else
			run.failed = run.failed + 1
			run.ok = false
		end

		emit({ kind = "task_end", name = name, status = entry.status, duration = entry.duration, result = entry })

		if (not run.ok) and (opts.fail_fast == true) then break end
	end

	emit({ kind = "runner_end", ok = run.ok, failed = run.failed, skipped = run.skipped, results = run.results })
	return run.ok, run
end

M.Runner = Runner

return M
