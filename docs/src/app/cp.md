# cp

`cp` copies files and directories.

> This module constructs `ward.process.cmd(...)` invocations; it does not parse output.
> consumers can use `wardlib.tools.out` (or their own parsing) on the `:output()`
> result.

## Import

```lua
local Cp = require("wardlib.app.cp").Cp
```

## Privilege escalation

This module does not implement `sudo`/`doas` options. When copying into
protected locations, use `wardlib.tools.with`.

```lua
local w = require("wardlib.tools.with")
local Cp = require("wardlib.app.cp").Cp

w.with(w.middleware.sudo(), Cp.copy("./app", "/srv/app", { recursive = true })):run()
```

## API

All functions return a `ward.process.cmd(...)` object.

### `Cp.bin`

Executable name or path used for `cp`.

### `Cp.copy(src, dest, opts)`

Builds: `cp <opts...> -- <src...> <dest>`

- `src: string|string[]` — one or more source paths.
- `dest: string` — destination path.
- `opts: CpOpts|nil` — modeled options.

### `Cp.into(src, dir, opts)`

Builds: `cp <opts...> -t <dir> -- <src...>`

This uses GNU-style `-t`. If your platform does not support `-t`,
prefer `Cp.copy(src, dir, ...)`.

### `Cp.raw(argv, opts)`

Low-level escape hatch.

Builds: `cp <modeled-opts...> <argv...>`

## Options (`CpOpts`)

- `recursive: boolean|nil` — `-r`.
- `force: boolean|nil` — `-f`.
- `interactive: boolean|nil` — `-i`.
- `update: boolean|nil` — `-u`.
- `verbose: boolean|nil` — `-v`.
- `preserve: boolean|nil` — `-p`.
- `archive: boolean|nil` — `-a`.
- `parents: boolean|nil` — GNU: `--parents`.
- `target_directory: string|nil` — GNU: `-t <dir>`.
- `no_target_directory: boolean|nil` — GNU: `-T`.
- `extra: string[]|nil` — pass-through args appended after modeled options.

Notes:

- `force` and `interactive` are mutually exclusive.

## Examples

### Copy multiple sources recursively

```lua
local Cp = require("wardlib.app.cp").Cp

-- cp -r -- a b dst
local cmd = Cp.copy({ "a", "b" }, "dst", { recursive = true })
```

### Copy into a directory (GNU `-t`)

```lua
local Cp = require("wardlib.app.cp").Cp

-- cp --parents -t out -- src/file
local cmd = Cp.into("src/file", "out", { parents = true })
```

### Raw escape hatch

```lua
local Cp = require("wardlib.app.cp").Cp

-- cp -a --reflink=auto -- a b
local cmd = Cp.raw({ "--reflink=auto", "--", "a", "b" }, { archive = true })
```
