# cfdisk

Thin wrapper around `cfdisk` (util-linux) for interactive partition editing.

> This module constructs `ward.process.cmd(...)` invocations; it does not parse output.
> consumers can use `wardlib.tools.out` (or their own parsing) on the `:output()`
> result.

`cfdisk` is interactive (curses UI). It is not suitable for non-interactive
automation; for scripted partitioning use `wardlib.app.sfdisk`.

## Import

```lua
local Cfdisk = require("wardlib.app.cfdisk").Cfdisk
```

## Privilege escalation

Partition editing typically requires elevated privileges. This module does not
implement `sudo`/`doas` options; use `wardlib.tools.with`.

```lua
local w = require("wardlib.tools.with")
local Cfdisk = require("wardlib.app.cfdisk").Cfdisk

w.with(w.middleware.sudo(), Cfdisk.edit("/dev/sda")):run()
```

## API

### `Cfdisk.bin`

Executable name or path used for `cfdisk`.

### `Cfdisk.edit(device, opts)`

Builds: `cfdisk <opts...> <device>`

- `device: string` — block device path (must not start with `-`).
- `opts: CfdiskOpts|nil` — modeled options.

## Options (`CfdiskOpts`)

- `color: "auto"|"never"|"always"|nil` — adds `--color[=<when>]`.
- `sector_size: integer|nil` — adds `--sector-size <n>`.
- `zero: boolean|nil` — adds `--zero`.
- `read_only: boolean|nil` — adds `--read-only`.
- `extra: string[]|nil` — pass-through args appended **before** the device.

## Examples

### Interactive partition editing

```lua
local Cfdisk = require("wardlib.app.cfdisk").Cfdisk

-- cfdisk /dev/sda
Cfdisk.edit("/dev/sda"):run()
```

### With modeled options + pass-through flags

```lua
local Cfdisk = require("wardlib.app.cfdisk").Cfdisk

-- cfdisk --color=never --sector-size 4096 --read-only --zero --wipe always /dev/sda
Cfdisk.edit("/dev/sda", {
  color = "never",
  sector_size = 4096,
  read_only = true,
  zero = true,
  extra = { "--wipe", "always" }, -- anything not modeled
}):run()
```
