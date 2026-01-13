# feh

`feh` is an image viewer that is often used for setting wallpapers in X11 environments.

The wrapper constructs a `ward.process.cmd(...)` invocation; it does not parse output.

## View images fullscreen

```lua
local Feh = require("wardlib.app.feh").Feh

-- Equivalent to: feh -F --randomize a.png b.png
local cmd = Feh.view({ "a.png", "b.png" }, {
  fullscreen = true,
  randomize = true,
})
```

## Set wallpaper

```lua
local Feh = require("wardlib.app.feh").Feh

-- Equivalent to: feh --bg-fill wall.png
local cmd = Feh.bg("wall.png", { mode = "fill" })
```

## Set wallpaper without writing ~/.fehbg

```lua
local Feh = require("wardlib.app.feh").Feh

-- Equivalent to: feh --bg-center --no-fehbg wall.png
local cmd = Feh.bg("wall.png", { mode = "center", no_fehbg = true })
```
