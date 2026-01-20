# swap

Wrappers around Linux swap tooling:

- `mkswap` — initialize a swap area
- `swapon` — enable swap
- `swapoff` — disable swap

> This module constructs `ward.process.cmd(...)` invocations; it does not parse output.
> consumers can use `wardlib.tools.out` (or their own parsing) on the `:output()`
> result.

Most swap operations require elevated privileges. Prefer using
[`wardlib.tools.with`](../tools/with.md) with the `sudo`/`doas` middleware.

## Import

```lua
local Swap = require("wardlib.app.swap").Swap
```

## API

### `Swap.mkswap(target, opts)`

Builds: `mkswap <opts...> <target>`

### `Swap.swapon(targets, opts)`

Builds: `swapon <opts...> [targets...]`

- If `targets` is `nil`, runs `swapon` with only modeled options (useful for `--show`).
- If `targets` is a string array, all targets are appended.

### `Swap.swapoff(targets, opts)`

Builds: `swapoff <opts...> [targets...]`

- If `targets` is `nil`, runs `swapoff` with only modeled options (useful for `-a`).

### `Swap.status(opts)`

Convenience: `swapon --show`.

### `Swap.disable_all(opts)`

Convenience: `swapoff -a`.

## Options

### `MkswapOpts`

- `label: string?` — `-L <label>`
- `uuid: string?` — `-U <uuid>`
- `pagesize: number?` — `--pagesize <size>`
- `force: boolean?` — `-f`
- `check: boolean?` — `-c` (check bad blocks)
- `extra: string[]?` — extra argv appended after modeled options

### `SwaponOpts`

- `all: boolean?` — `-a`
- `discard: string?` — `--discard[=<policy>]`
  - pass `""` (empty string) to emit bare `--discard`
- `fixpgsz: boolean?` — `--fixpgsz`
- `priority: number?` — `-p <prio>`

Formatting for `--show`:

- `show: boolean?` — `--show`
- `noheadings: boolean?` — `--noheadings`
- `raw: boolean?` — `--raw`
- `bytes: boolean?` — `--bytes`
- `output: string|string[]?` — `--output <cols>` (array is joined by `,`)

Escape hatch:

- `extra: string[]?` — extra argv appended after modeled options

### `SwapoffOpts`

- `all: boolean?` — `-a`
- `verbose: boolean?` — `-v`
- `extra: string[]?` — extra argv appended after modeled options

## Examples

### Create swap on a file (mkswap + swapon)

This example shows the command construction only. File allocation (fallocate/dd)
is handled elsewhere.

```lua
local Swap = require("wardlib.app.swap").Swap
local w = require("wardlib.tools.with")

w.with(w.middleware.sudo(), function()
  -- mkswap -f -L swap0 /swapfile
  Swap.mkswap("/swapfile", { force = true, label = "swap0" }):run()

  -- swapon /swapfile
  Swap.swapon("/swapfile"):run()
end)
```

### Disable a specific swap and remove it from service

```lua
local Swap = require("wardlib.app.swap").Swap
local w = require("wardlib.tools.with")

w.with(w.middleware.sudo(), function()
  -- swapoff /swapfile
  Swap.swapoff("/swapfile"):run()
end)
```

### Show active swaps

```lua
local Swap = require("wardlib.app.swap").Swap

-- swapon --show --noheadings --output NAME,SIZE,USED,PRIO
local cmd = Swap.status({
  noheadings = true,
  output = { "NAME", "SIZE", "USED", "PRIO" },
})

-- cmd:output().stdout contains the table. Use wardlib.tools.out if you need parsing.
```

### Enable all swaps from /etc/fstab

```lua
local Swap = require("wardlib.app.swap").Swap
local w = require("wardlib.tools.with")

w.with(w.middleware.sudo(), Swap.swapon(nil, { all = true }))
  :run()
```

### Disable all swaps

```lua
local Swap = require("wardlib.app.swap").Swap
local w = require("wardlib.tools.with")

w.with(w.middleware.sudo(), Swap.disable_all())
  :run()
```
