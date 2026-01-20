# swaybg

`swaybg` sets wallpapers/backgrounds for Wayland compositors based on wlroots
(e.g. Sway).

> This module constructs `ward.process.cmd(...)` invocations; it does not parse output.
> consumers can use `wardlib.tools.out` (or their own parsing) on the `:output()`
> result.

Notes:

- `swaybg` is typically a long-running process (it stays alive to keep the
background set).
- The wrapper only builds the command. Starting it in the background or
managing its lifecycle is the caller's responsibility.

## Import

```lua
local Swaybg = require("wardlib.app.swaybg").Swaybg
```

## API

### `Swaybg.set(image, mode, color)`

Convenience for a single output.

Builds: `swaybg -i <image> [-m <mode>] [-c <color>]`

### `Swaybg.run(opts)`

Full control. Builds one or more output blocks.

Builds: `swaybg (-o <name> -i <image> [-m <mode>] [-c <color>])+ <extra...>`

## Options

### `SwaybgMode`

One of:

- `"stretch" | "fill" | "fit" | "center" | "tile"`

### `SwaybgOutput`

- `name: string?` — output name (e.g. `"DP-1"`)
- `image: string` — path to image
- `mode: SwaybgMode?` — scaling mode
- `color: string?` — background color (hex or name)

### `SwaybgOpts`

- `outputs: SwaybgOutput|SwaybgOutput[]` — one or more output specs (required)
- `extra: string[]?` — extra argv appended after modeled options

## Examples

### Set wallpaper for the default output

```lua
local Swaybg = require("wardlib.app.swaybg").Swaybg

-- Equivalent to: swaybg -i wall.png -m fill -c #000000
local cmd = Swaybg.set("wall.png", "fill", "#000000")
```

### Set wallpapers per-output

```lua
local Swaybg = require("wardlib.app.swaybg").Swaybg

-- Equivalent to:
--   swaybg -o DP-1 -i a.png -m fit \
--         -o HDMI-A-1 -i b.png -m fill -c #111111
local cmd = Swaybg.run({
  outputs = {
    { name = "DP-1", image = "a.png", mode = "fit" },
    { name = "HDMI-A-1", image = "b.png", mode = "fill", color = "#111111" },
  },
})
```

### Pass-through flags via `extra`

```lua
local Swaybg = require("wardlib.app.swaybg").Swaybg

-- Example: swaybg -i wall.png -m fill --some-flag
local cmd = Swaybg.run({
  outputs = { image = "wall.png", mode = "fill" },
  extra = { "--some-flag" },
})
```
