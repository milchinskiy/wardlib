# tools.task

`tools.task` is a small, Ward-native task runner for organizing scripts into
named steps with dependencies.

It is designed for:

- Deterministic execution order (definition order plus explicit dependency
order).
- Simple dependency graphs (DAG) with cycle detection.
- Conditional execution (`when`) and dry runs.
- Structured results suitable for CI/logging.
- No side effects: it does not print and it does not exit the process.

Non-goals (for now): parallel execution, persistent state storage, and tight
coupling to `tools.cli`.

## Quick example

```lua
local task = require("wardlib.tools.task")

local r = task.runner({
  default = "apply",
})

r:define("packages", function(ctx)
  -- install packages...
end, { desc = "Install packages" })

r:define("dotfiles", function(ctx)
  -- apply dotfiles...
end, { desc = "Apply dotfiles" })

r:define("apply", function(ctx)
  -- umbrella task
end, {
  desc = "Apply workstation setup",
  deps = { "packages", "dotfiles" },
})

local ok, report = r:run() -- runs default task
if not ok then
  -- report.failed > 0
  error("Task run failed")
end
```

## API

### `task.runner(opts?) -> runner`

Creates a runner.

`opts`:

- `default` (string|nil): task name used when `runner:run()` is called without
an explicit task name.

### `runner:define(name, fn, meta?) -> runner`

Defines a task.

- `name` (string, required): task name.
- `fn(ctx, runner)` (function, required): task body.
- `meta` (table|nil):
  - `desc` (string|nil): human-readable description.
  - `deps` (string[]|nil): dependency task names.
  - `when(ctx, runner)` (function|nil): if provided and returns `false`, the
  task is skipped.

Task function return conventions:

- `nil` or `true` => success (`status="ok"`).
- `{ status = "ok" }` => success.
- `{ status = "skip", reason = "..." }` => skipped.
- `{ status = "error", error = "..." }` => recorded as failure.
- Any other return value => treated as success and stored as `value`.

### `runner:list() -> taskinfo[]`

Returns tasks in definition order. Each entry has:

- `name`
- `desc`
- `deps`

### `runner:plan(names?) -> (ok, plan_or_err)`

Computes a deterministic execution plan.

- `names` may be:
  - `nil`: uses `opts.default` (error if no default is set).
  - a string: a single task name.
  - a string[]: multiple tasks.

On success: `ok=true`, `plan` is a string[] of task names in execution order.

On failure: `ok=false`, `err` is a table with:

- `err.code` (string): e.g. `"missing_task"` or `"cycle"`.
- `err.message` (string)

### `runner:run(names?, ctx?, run_opts?) -> (ok, report)`

Runs the plan and returns a structured report.

- `names`: same as `runner:plan`.
- `ctx` (table|nil): user context passed to tasks.
- `run_opts`:
  - `dry_run` (boolean|nil): if true, all tasks are skipped with reason `"dry_run"`.
  - `fail_fast` (boolean|nil): if true, stop after the first task failure.
  - `on_event(ev)` (function|nil): event callback.

`report` contains:

- `ok` (boolean)
- `total`, `failed`, `skipped` (numbers)
- `plan` (string[])
- `results` (array): one entry per planned task, in execution order:
  - `name`
  - `status` (`"ok"|"skip"|"error"`)
  - `reason` (string|nil)
  - `error` (string|nil)
  - `value` (any|nil)
  - `duration` (number|nil) seconds when timing is available

## Events

If `run_opts.on_event` is provided, `tools.task` emits events:

- `runner_start`: `{ kind="runner_start", requested={...}, plan={...} }`
- `task_start`: `{ kind="task_start", name=..., index=i, total=n }`
- `task_end`: `{ kind="task_end", name=..., status=..., duration=..., result=... }`
- `runner_end`: `{ kind="runner_end", ok=..., failed=..., skipped=..., results=... }`
