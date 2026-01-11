# rm

`rm` removes directory entries.

> This wrapper constructs a `ward.process.cmd(...)` invocation; it does
> not parse output.

## Import

```lua
local Rm = require("app.rm").Rm
```

## API

### `Rm.remove(paths, opts)`

Builds: `rm <opts...> -- <paths...>`

### `Rm.raw(argv, opts)`

Builds: `rm <opts...> <argv...>`

## Options (`RmOpts`)

Common fields:

- `force (-f)` and `interactive (-i)` are mutually exclusive
- `recursive (-r)`
- `dir (-d)` (remove empty directories)
- GNU-only: `verbose (-v)`
- Escape hatch: `extra`

## Examples

```lua
local Rm = require("app.rm").Rm

-- rm -f -r -- build dist
local cmd1 = Rm.remove({ "build", "dist" }, { force = true, recursive = true })
```
