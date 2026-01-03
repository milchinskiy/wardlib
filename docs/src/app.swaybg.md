# swaybg

`swaybg` sets wallpaper/backgrounds for Wayland compositors based on wlroots (e.g., sway).

The wrapper constructs a `ward.process.cmd(...)` invocation; it does not parse output.

## Set wallpaper for the default output

```lua
local Swaybg = require("app.swaybg").Swaybg

-- Equivalent to: swaybg -i wall.png -m fill -c #000000
local cmd = Swaybg.set("wall.png", "fill", "#000000")
```

## Set wallpapers per-output

```lua
local Swaybg = require("app.swaybg").Swaybg

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
