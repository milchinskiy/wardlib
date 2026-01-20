# chown

`chown` changes file owner and group.

> This module constructs `ward.process.cmd(...)` invocations; it does not parse output.
> consumers can use `wardlib.tools.out` (or their own parsing) on the `:output()`
> result.

## Import

```lua
local Chown = require("wardlib.app.chown").Chown
```

## Privilege escalation

Changing ownership typically requires elevated privileges. This module does
not implement `sudo`/`doas` options; use `wardlib.tools.with`.

```lua
local w = require("wardlib.tools.with")
local Chown = require("wardlib.app.chown").Chown

w.with(w.middleware.sudo(), Chown.set("/srv/app", "root", "root", { recursive = true })):run()
```

## API

### `Chown.bin`

Executable name or path used for `chown`.

### `Chown.set(paths, owner, group, opts)`

Builds: `chown <opts...> -- <owner[:group]> <paths...>`

- `paths: string|string[]` — one or more paths.
- `owner: string|nil` — owner (user name or numeric id).
- `group: string|nil` — group (group name or numeric id).
- `opts: ChownOpts|nil` — modeled options.

Rules:

- Provide `owner`, `group`, or both.
- If `owner` is `nil` and `group` is not `nil`, the wrapper emits `:<group>`.

### `Chown.raw(argv, opts)`

Low-level escape hatch.

Builds: `chown <modeled-opts...> <argv...>`

## Options (`ChownOpts`)

- `recursive: boolean|nil` — `-R`.
- `verbose: boolean|nil` — `-v`.
- `changes: boolean|nil` — `-c`.
- `silent: boolean|nil` — `-f`.
- `dereference: boolean|nil` — `-h` (affects symlinks).
- `preserve_root: boolean|nil` — GNU: `--preserve-root`.
- `no_preserve_root: boolean|nil` — GNU: `--no-preserve-root`.
- `extra: string[]|nil` — pass-through args appended after modeled options.

Notes:

- `preserve_root` and `no_preserve_root` are mutually exclusive.

## Examples

### Set owner and group recursively

```lua
local Chown = require("wardlib.app.chown").Chown

-- chown -R -- root:root /srv/app
local cmd = Chown.set("/srv/app", "root", "root", { recursive = true })
```

### Change group only

```lua
local Chown = require("wardlib.app.chown").Chown

-- chown -- :wheel somefile
local cmd = Chown.set("somefile", nil, "wheel")
```
