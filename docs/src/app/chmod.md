# chmod

`chmod` changes file mode bits.

> This module constructs `ward.process.cmd(...)` invocations; it does not parse output.
> consumers can use `wardlib.tools.out` (or their own parsing) on the `:output()`
> result.

## Import

```lua
local Chmod = require("wardlib.app.chmod").Chmod
```

## Privilege escalation

Changing mode on root-owned paths requires elevated privileges. This module
does not implement `sudo`/`doas` options; use `wardlib.tools.with`.

```lua
local w = require("wardlib.tools.with")
local Chmod = require("wardlib.app.chmod").Chmod

w.with(w.middleware.sudo(), Chmod.set("/srv/app", "0755", { recursive = true })):run()
```

## API

### `Chmod.bin`

Executable name or path used for `chmod`.

### `Chmod.set(paths, mode, opts)`

Builds: `chmod <opts...> -- <mode> <paths...>`

- `paths: string|string[]` — one or more paths.
- `mode: string` — mode string (e.g. `0755`, `u+rwx`, `a-w`).
- `opts: ChmodOpts|nil` — modeled options.

### `Chmod.reference(paths, ref, opts)`

GNU-style reference mode.

Builds: `chmod <opts...> --reference=<ref> -- <paths...>`

- `ref: string` — reference file path.

### `Chmod.raw(argv, opts)`

Low-level escape hatch.

Builds: `chmod <modeled-opts...> <argv...>`

## Options (`ChmodOpts`)

- `recursive: boolean|nil` — `-R`.
- `verbose: boolean|nil` — `-v`.
- `changes: boolean|nil` — `-c`.
- `silent: boolean|nil` — `-f`.
- `reference: string|nil` — GNU: `--reference=<file>`.
- `preserve_root: boolean|nil` — GNU: `--preserve-root`.
- `no_preserve_root: boolean|nil` — GNU: `--no-preserve-root`.
- `extra: string[]|nil` — pass-through args appended after modeled options.

Notes:

- `preserve_root` and `no_preserve_root` are mutually exclusive.

## Examples

### Set recursive numeric mode

```lua
local Chmod = require("wardlib.app.chmod").Chmod

-- chmod -R -- 0755 bin
local cmd = Chmod.set("bin", "0755", { recursive = true })
```

### Copy mode from a reference file

```lua
local Chmod = require("wardlib.app.chmod").Chmod

-- chmod --reference=ref -- target
local cmd = Chmod.reference("target", "ref")
```
