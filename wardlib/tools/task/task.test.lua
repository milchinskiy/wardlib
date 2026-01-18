-- Tinytest suite for tools.task
--
-- This suite avoids Ward-specific dependencies by not requiring any Ward modules
-- directly. tools.task uses Ward time only optionally (best-effort).

return function(tinytest)
	local t = tinytest.new({ name = "tools.task" })

	local MODULE = "wardlib.tools.task"
	local loaded_orig = package.loaded[MODULE]

	local function reload()
		package.loaded[MODULE] = nil
		return require(MODULE)
	end

	t:after_all(function() package.loaded[MODULE] = loaded_orig end)

	t:test("define + list returns deterministic order", function()
		local task = reload()
		local r = task.runner({ default = "a" })

		r:define("b", function() end)
		r:define("a", function() end)

		local list = r:list()
		t:eq(#list, 2)
		t:eq(list[1].name, "b")
		t:eq(list[2].name, "a")
	end)

	t:test("plan resolves deps in order and dedups", function()
		local task = reload()
		local r = task.runner({ default = "a" })

		r:define("c", function() end)
		r:define("b", function() end, { deps = { "c" } })
		r:define("a", function() end, { deps = { "b", "c" } })

		local ok, plan = r:plan("a")
		t:truthy(ok)
		t:deep_eq(plan, { "c", "b", "a" })
	end)

	t:test("plan errors on missing dependency", function()
		local task = reload()
		local r = task.runner({ default = "a" })
		r:define("a", function() end, { deps = { "missing" } })

		local ok, err = r:plan("a")
		t:falsy(ok)
		t:eq(err.code, "unknown_dep")
		t:match(err.message, "missing")
	end)

	t:test("plan errors on cycles", function()
		local task = reload()
		local r = task.runner({ default = "a" })
		r:define("a", function() end, { deps = { "b" } })
		r:define("b", function() end, { deps = { "a" } })

		local ok, err = r:plan("a")
		t:falsy(ok)
		t:eq(err.code, "cycle")
		t:match(err.message, "a")
	end)

	t:test("run executes in planned order and returns per-task results", function()
		local task = reload()
		local r = task.runner({ default = "a" })

		local seen = {}
		r:define("c", function() seen[#seen + 1] = "c" end)
		r:define("b", function() seen[#seen + 1] = "b" end, { deps = { "c" } })
		r:define("a", function() seen[#seen + 1] = "a" end, { deps = { "b" } })

		local ok, rep = r:run("a")
		t:truthy(ok)
		t:deep_eq(seen, { "c", "b", "a" })
		t:eq(rep.total, 3)
		t:eq(rep.failed, 0)
		t:eq(rep.skipped, 0)
		-- deterministic order in report
		t:eq(rep.results[1].name, "c")
		t:eq(rep.results[2].name, "b")
		t:eq(rep.results[3].name, "a")
	end)

	t:test("run respects when predicate (skip)", function()
		local task = reload()
		local r = task.runner({ default = "a" })

		local ran = false
		r:define("a", function() ran = true end, {
			when = function(ctx) return ctx and ctx.enabled end,
		})

		local ok, rep = r:run("a", { enabled = false })
		t:truthy(ok)
		t:falsy(ran)
		t:eq(rep.skipped, 1)
		t:eq(rep.results[1].status, "skip")
	end)

	t:test("run respects dry_run", function()
		local task = reload()
		local r = task.runner({ default = "a" })

		local ran = false
		r:define("a", function() ran = true end)

		local ok, rep = r:run("a", {}, { dry_run = true })
		t:truthy(ok)
		t:falsy(ran)
		t:eq(rep.skipped, 1)
		t:eq(rep.results[1].reason, "dry_run")
	end)

	t:test("run marks failures and stops when fail_fast", function()
		local task = reload()
		local r = task.runner({ default = "a" })

		local ran_b = false
		r:define("a", function() error("boom") end)
		r:define("b", function() ran_b = true end)

		local ok, rep = r:run({ "a", "b" }, {}, { fail_fast = true })
		t:falsy(ok)
		t:falsy(ran_b)
		t:eq(rep.failed, 1)
		t:eq(rep.results[1].status, "error")
	end)

	return t
end
