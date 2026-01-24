# rofi

`rofi` is a popular application launcher / window switcher.

> This module constructs `ward.process.cmd(...)` invocations; it does not parse output.
> consumers can use `wardlib.tools.out` (or their own parsing) on the `:output()`
> result.

## Import

```lua
local Rofi = require("wardlib.app.rofi").Rofi
```

## API

### `Rofi.bin`

Executable name or path (default: `"rofi"`).

### `Rofi.dmenu(opts)`

Builds: `rofi <common...> -dmenu <dmenu...>`

### `Rofi.show(mode, opts)`

Builds: `rofi <common...> -show <mode> <extra...>`

## Options

### `RofiCommonOpts`

- `config: string?` → `-config <file>`
- `theme: string?` → `-theme <theme>`
- `theme_str: string?` → `-theme-str <string>`
- `modi: string?` → `-modi <modes>`
- `show_icons: boolean?` → `-show-icons`
- `terminal: string?` → `-terminal <terminal>`
- `extra: string[]?` → extra argv appended after modeled options

### `RofiDmenuOpts`

Extends `RofiCommonOpts` and adds:

- `sep: string?` → `-sep <sep>`
- `prompt: string?` → `-p <prompt>`
- `lines: number?` → `-l <n>`
- `insensitive: boolean?` → `-i`
- `only_match: boolean?` → `-only-match`
- `no_custom: boolean?` → `-no-custom`
- `format: string?` → `-format <fmt>`
- `select: string?` → `-select <string>`
- `mesg: string?` → `-mesg <msg>`
- `password: boolean?` → `-password`
- `markup_rows: boolean?` → `-markup-rows`
- `multi_select: boolean?` → `-multi-select`
- `sync: boolean?` → `-sync`
- `input: string?` → `-input <file>`
- `window_title: string?` → `-window-title <title>`
- `windowid: string?` → `-w <windowid>`

## Examples

### `run` launcher

```lua
local Rofi = require("wardlib.app.rofi").Rofi

Rofi.show("run", {
  modi = "run,drun",
  show_icons = true,
}):output()
```

### `-dmenu` mode

```lua
local Rofi = require("wardlib.app.rofi").Rofi

Rofi.dmenu({ prompt = "Run" }):output()
```
