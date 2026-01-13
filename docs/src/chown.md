# chown

`chown` changes file owner and group.

> This wrapper constructs a `ward.process.cmd(...)` invocation; it does not
> parse output.

## Import

```lua
local Chown = require("wardlib.app.chown").Chown
```

## API

### `Chown.set(paths, owner, group, opts)`

Builds: `chown <opts...> -- <owner[:group]> <paths...>`

Rules:

- Provide `owner`, `group`, or both.
- If `owner` is nil and `group` is not nil, the wrapper emits `:<group>`.

### `Chown.raw(argv, opts)`

Builds: `chown <opts...> <argv...>`

## Options (`ChownOpts`)

Modeled fields:

- `recursive (-R)`
- `verbose (-v)`, `changes (-c)`, `silent (-f)`
- `dereference (-h)` (affects symlinks)
- GNU-only: `preserve_root`, `no_preserve_root`
- Escape hatch: `extra`

## Examples

```lua
local Chown = require("wardlib.app.chown").Chown

-- chown -R -- root:root /srv/app
local cmd1 = Chown.set("/srv/app", "root", "root", { recursive = true })

-- chown -- :wheel somefile
local cmd2 = Chown.set("somefile", nil, "wheel")
```
