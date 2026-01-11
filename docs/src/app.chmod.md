# chmod

`chmod` changes file mode bits.

> This wrapper constructs a `ward.process.cmd(...)` invocation; it does not
> parse output.

## Import

```lua
local Chmod = require("app.chmod").Chmod
```

## API

### `Chmod.set(paths, mode, opts)`

Builds: `chmod <opts...> -- <mode> <paths...>`

### `Chmod.reference(paths, ref, opts)`

Builds: `chmod <opts...> --reference=<ref> -- <paths...>`

This is GNU-style `--reference`.

### `Chmod.raw(argv, opts)`

Builds: `chmod <opts...> <argv...>`

## Options (`ChmodOpts`)

Modeled fields:

- `recursive (-R)`
- `verbose (-v)`, `changes (-c)`, `silent (-f)`
- GNU-only: `reference (--reference=...)`, `preserve_root`, `no_preserve_root`
- Escape hatch: `extra`

## Examples

```lua
local Chmod = require("app.chmod").Chmod

-- chmod -R -- 0755 bin
local cmd1 = Chmod.set("bin", "0755", { recursive = true })

-- chmod --reference=ref -- target
local cmd2 = Chmod.reference("target", "ref")
```
