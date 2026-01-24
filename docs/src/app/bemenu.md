# bemenu

`bemenu` is a Wayland-native dynamic menu inspired by `dmenu`.

> This module constructs `ward.process.cmd(...)` invocations; it does not parse output.
> consumers can use `wardlib.tools.out` (or their own parsing) on the `:output()`
> result.

## Import

```lua
local Bemenu = require("wardlib.app.bemenu").Bemenu
```

## API

### `Bemenu.bin`

Executable name or path (default: `"bemenu"`).

### `Bemenu.bin_run`

Executable name or path (default: `"bemenu-run"`).

### `Bemenu.menu(opts)`

Builds: `bemenu <opts...>`

### `Bemenu.run(opts)`

Builds: `bemenu-run <opts...>`

## Options

### `BemenuOpts`

- `prompt: string?` → `-p <text>`
- `lines: number?` → `-l <n>`
- `ignorecase: boolean?` → `-i`
- `center: boolean?` → `-c`
- `fork: boolean?` → `-f`
- `no_cursor: boolean?` → `-C`
- `extra: string[]?` → extra argv appended after modeled options

## Examples

```lua
local Bemenu = require("wardlib.app.bemenu").Bemenu

Bemenu.menu({ prompt = "Run", lines = 10 }):output()
```
