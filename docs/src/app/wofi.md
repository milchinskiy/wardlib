# wofi

`wofi` is a Wayland-native menu / launcher.

> This module constructs `ward.process.cmd(...)` invocations; it does not parse output.
> consumers can use `wardlib.tools.out` (or their own parsing) on the `:output()`
> result.

## Import

```lua
local Wofi = require("wardlib.app.wofi").Wofi
```

## API

### `Wofi.bin`

Executable name or path (default: `"wofi"`).

### `Wofi.dmenu(opts)`

Builds: `wofi <opts...> --dmenu`

### `Wofi.show(mode, opts)`

Builds: `wofi <opts...> --show <mode>`

## Options

### `WofiOpts`

- `conf: string?` → `--conf <file>`
- `style: string?` → `--style <file>`
- `prompt: string?` → `--prompt <text>`
- `term: string?` → `--term <terminal>`
- `cache_file: string?` → `--cache-file <file>`
- `width: string?` → `--width <width>`
- `height: string?` → `--height <height>`
- `lines: number?` → `--lines <n>`
- `columns: number?` → `--columns <n>`
- `insensitive: boolean?` → `--insensitive`
- `show_icons: boolean?` → `--allow-images`
- `allow_markup: boolean?` → `--allow-markup`
- `gtk_dark: boolean?` → `--gtk-dark`
- `normal_window: boolean?` → `--normal-window`
- `extra: string[]?` → extra argv appended after modeled options

## Examples

### `--show drun`

```lua
local Wofi = require("wardlib.app.wofi").Wofi

Wofi.show("drun", { prompt = "Run" }):output()
```

### `--dmenu`

```lua
local Wofi = require("wardlib.app.wofi").Wofi

Wofi.dmenu({ prompt = "Pick" }):output()
```
