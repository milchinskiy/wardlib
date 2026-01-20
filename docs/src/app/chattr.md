# chattr

`chattr` changes file attributes on Linux filesystems.

> This module constructs `ward.process.cmd(...)` invocations; it does not parse output.
> consumers can use `wardlib.tools.out` (or their own parsing) on the `:output()`
> result.

## Import

```lua
local Chattr = require("wardlib.app.chattr").Chattr
```

## Privilege escalation

Changing attributes frequently requires elevated privileges. This module does
not implement `sudo`/`doas` options; use `wardlib.tools.with`.

```lua
local w = require("wardlib.tools.with")
local Chattr = require("wardlib.app.chattr").Chattr

w.with(w.middleware.sudo(), Chattr.set("important.txt", "+i")):run()
```

## API

### `Chattr.bin`

Executable name or path used for `chattr`.

### `Chattr.set(paths, mode, opts)`

Builds: `chattr <opts...> -- <mode> <paths...>`

- `paths: string|string[]` — one or more paths (must be non-empty).
- `mode: string` — attribute mode string (examples: `+i`, `-i`, `=ai`).
- `opts: ChattrOpts|nil` — modeled options.

### `Chattr.raw(argv, opts)`

Low-level escape hatch.

Builds: `chattr <modeled-opts...> <argv...>`

## Options (`ChattrOpts`)

- `recursive: boolean|nil` — `-R`.
- `verbose: boolean|nil` — `-V`.
- `force: boolean|nil` — `-f`.
- `version: integer|nil` — `-v <version>`.
- `extra: string[]|nil` — pass-through args appended after modeled options.

## Examples

### Make a file immutable

```lua
local Chattr = require("wardlib.app.chattr").Chattr

-- chattr -- +i important.txt
local cmd = Chattr.set("important.txt", "+i")
```

### Clear immutable recursively

```lua
local Chattr = require("wardlib.app.chattr").Chattr

-- chattr -R -- -i /srv/app
local cmd = Chattr.set("/srv/app", "-i", { recursive = true })
```
