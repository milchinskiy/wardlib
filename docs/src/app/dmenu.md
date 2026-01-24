# dmenu

`dmenu` is a simple X11 menu / launcher that reads newline-separated entries
from stdin and prints the selected entry to stdout.

> This module constructs `ward.process.cmd(...)` invocations; it does not parse output.
> consumers can use `wardlib.tools.out` (or their own parsing) on the `:output()`
> result.

## Import

```lua
local Dmenu = require("wardlib.app.dmenu").Dmenu
```

## API

### `Dmenu.bin`

Executable name or path (default: `"dmenu"`).

### `Dmenu.menu(opts)`

Builds: `dmenu <opts...>`

Returns a `ward.Cmd`.

## Options

### `DmenuOpts`

Flags:

- `bottom: boolean?` → `-b`
- `fast: boolean?` → `-f`
- `insensitive: boolean?` → `-i`

Values:

- `lines: number?` → `-l <n>`
- `monitor: number?` → `-m <n>`
- `prompt: string?` → `-p <text>`
- `font: string?` → `-fn <font>`
- `normal_bg: string?` → `-nb <color>`
- `normal_fg: string?` → `-nf <color>`
- `selected_bg: string?` → `-sb <color>`
- `selected_fg: string?` → `-sf <color>`
- `windowid: string?` → `-w <id>`

Other:

- `extra: string[]?` → extra argv appended after modeled options

## Examples

### Run dmenu with a prompt

```lua
local Dmenu = require("wardlib.app.dmenu").Dmenu

-- Feed items via stdin using ward.process APIs.
local cmd = Dmenu.menu({ prompt = "Run:" })

-- Example only: how you provide stdin depends on your ward version.
-- Typically you'd do: cmd:input("..."):output() or similar.
```
