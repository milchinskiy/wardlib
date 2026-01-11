# cp

`cp` copies files and directories.

> This wrapper constructs a `ward.process.cmd(...)` invocation; it does not
> parse output.

## Import

```lua
local Cp = require("app.cp").Cp
```

## API

### `Cp.copy(src, dest, opts)`

Builds: `cp <opts...> -- <src...> <dest>`

### `Cp.into(src, dir, opts)`

Builds: `cp <opts...> -t <dir> -- <src...>`

This uses GNU-style `-t`. If your platform does not support `-t`, prefer
`Cp.copy(src, dir, ...)`.

### `Cp.raw(argv, opts)`

Builds: `cp <opts...> <argv...>`

## Options (`CpOpts`)

Common fields:

- `recursive` (`-r`)
- `force` (`-f`) and `interactive` (`-i`) are mutually exclusive
- `update` (`-u`), `verbose` (`-v`)
- `preserve` (`-p`), `archive` (`-a`)
- GNU-only convenience: `parents` (`--parents`), `target_directory`
(`-t <dir>`), `no_target_directory` (`-T`)
- Escape hatch: `extra`

## Examples

```lua
local Cp = require("app.cp").Cp

-- cp -r -- a b dst
local cmd1 = Cp.copy({ "a", "b" }, "dst", { recursive = true })

-- cp --parents -t out -- src/file
local cmd2 = Cp.into("src/file", "out", { parents = true })
```
