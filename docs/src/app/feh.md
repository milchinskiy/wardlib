# feh

`feh` is an image viewer that is often used for setting wallpapers in X11 environments.

> This module constructs `ward.process.cmd(...)` invocations; it does not parse output.
> consumers can use `wardlib.tools.out` (or their own parsing) on the `:output()`
> result.

## Import

```lua
local Feh = require("wardlib.app.feh").Feh
```

## API

### `Feh.view(inputs, opts)`

Builds: `feh <opts...> [inputs...]`

- `inputs`: `string|string[]|nil`
  - If `nil`, `feh` runs with only options.

### `Feh.bg(image, opts)`

Builds: `feh <bg-opts...> <image>`

### `Feh.bg_multi(images, opts)`

Builds: `feh <bg-opts...> <images...>`

All functions return a `ward.process.cmd(...)` object.

## Options

### `FehOpts`

- View mode: `fullscreen` (`-F`), `borderless` (`-x`)
- Zoom/rotation: `keep_zoom_vp` (`--keep-zoom-vp`), `zoom` (`-Z`),
`zoom_percent` (`--zoom <percent>`), `auto_rotate` (`--auto-rotate`)
- UI: `draw_filename` (`-d`), `caption_path` (`--caption-path`), `title` (`--title`)
- Geometry/timing: `geometry` (`-g`), `reload` (`--reload <sec>`),
`slideshow_delay` (`-D <sec>`)
- Traversal: `recursive` (`-r`)
- Ordering: `sort` (`--sort <mode>`), `reverse` (`--reverse`),
`randomize` (`--randomize`)
- Performance: `preload` (`--preload`), `cache_size` (`--cache-size <MB>`)
- Escape hatch: `extra`

### `FehBgOpts`

- `mode`: `"center"|"fill"|"max"|"scale"|"tile"` (maps to `--bg-*`)
- `no_fehbg`: `--no-fehbg`
- Escape hatch: `extra`

## Examples

### View images fullscreen

```lua
local Feh = require("wardlib.app.feh").Feh

-- feh -F --randomize a.png b.png
local cmd = Feh.view({ "a.png", "b.png" }, {
  fullscreen = true,
  randomize = true,
})
```

### Set wallpaper

```lua
local Feh = require("wardlib.app.feh").Feh

-- feh --bg-fill wall.png
Feh.bg("wall.png", { mode = "fill" }):run()
```

### Set wallpaper without writing ~/.fehbg

```lua
local Feh = require("wardlib.app.feh").Feh

-- feh --bg-center --no-fehbg wall.png
Feh.bg("wall.png", { mode = "center", no_fehbg = true }):run()
```

### Set multiple wallpapers (e.g. multi-monitor)

```lua
local Feh = require("wardlib.app.feh").Feh

-- feh --bg-scale left.png right.png
Feh.bg_multi({ "left.png", "right.png" }, { mode = "scale" }):run()
```
