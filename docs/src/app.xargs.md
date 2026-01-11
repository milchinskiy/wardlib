# xargs

`xargs` builds and executes command lines from standard input.

> This wrapper constructs a `ward.process.cmd(...)` invocation; it does not
> parse output.

Notes:

- GNU/BSD `xargs` differ slightly. Use `extra` to access unmodeled features.

## Import

```lua
local Xargs = require("app.xargs").Xargs
```

## API

### `Xargs.run(cmd, opts)`

Builds: `xargs <opts...> [-- <cmd...>]`

- If `cmd` is nil, `xargs` executes its default command (commonly `echo`,
implementation-dependent).
- When `cmd` is provided, this wrapper emits `--` before the command.

### `Xargs.raw(argv, opts)`

Builds: `xargs <opts...> <argv...>`

## Options (`XargsOpts`)

Common fields:

- Input parsing: `null_input (-0)` or `delimiter (-d <delim>)` (mutually exclusive)
- Limits: `max_args (-n)`, `max_procs (-P)`, `max_chars (-s)`
- Behavior: `no_run_if_empty (-r)` (GNU)
- Replacement: `replace_str (-I <str>)`
- Debug: `verbose (-t)`, `show_limits (--show-limits)` (GNU)
- Escape hatch: `extra`

## Examples

```lua
local Xargs = require("app.xargs").Xargs

-- xargs -n 10 -t -- echo {}
local cmd1 = Xargs.run({ "echo", "{}" }, { max_args = 10, verbose = true })

-- xargs -0 -P 4 -- rm -f
local cmd2 = Xargs.run({ "rm", "-f" }, { null_input = true, max_procs = 4 })
```
