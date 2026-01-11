# mv

`mv` moves (renames) files and directories.

> This wrapper constructs a `ward.process.cmd(...)` invocation; it does
> not parse output.

## Import

```lua
local Mv = require("app.mv").Mv
```

## API

### `Mv.move(src, dest, opts)`

Builds: `mv <opts...> -- <src...> <dest>`

### `Mv.into(src, dir, opts)`

Builds: `mv <opts...> -t <dir> -- <src...>`

This uses GNU-style `-t`. If your platform does not support `-t`, prefer
`Mv.move(src, dir, ...)`.

### `Mv.raw(argv, opts)`

Builds: `mv <opts...> <argv...>`

## Options (`MvOpts`)

Common fields:

- `force (-f)` and `interactive (-i)` are mutually exclusive
- `update (-u)`, `verbose (-v)`
- GNU-only: `no_clobber (-n)`, `backup (--backup)`, `suffix (--suffix=...)`,
`target_directory (-t)`, `no_target_directory (-T)`
- Escape hatch: `extra`

## Examples

```lua
local Mv = require("app.mv").Mv

-- mv -v -- a b dst
local cmd1 = Mv.move({ "a", "b" }, "dst", { verbose = true })
```
