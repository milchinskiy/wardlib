# wl-copy / wl-paste

`wardlib.app.wlcopy` is a thin wrapper around Wayland clipboard tools:

- `wl-copy`
- `wl-paste`

> This module constructs `ward.process.cmd(...)` invocations; it does not parse output.
> consumers can use `wardlib.tools.out` (or their own parsing) on the `:output()`
> result.

Notes:

- `wl-copy` reads data from stdin. This module only builds the command; feeding
stdin is the caller's responsibility.
- Use [`wardlib.tools.out`](../tools/out.md) if you want predictable parsing of
`wl-paste` output.

## Import

```lua
local Clipboard = require("wardlib.app.wlcopy").Clipboard
```

## API

### `Clipboard.copy(opts)`

Builds: `wl-copy <opts...>`

### `Clipboard.clear(opts)`

Convenience: `Clipboard.copy({ clear = true, selection = ... })`.

### `Clipboard.paste(opts)`

Builds: `wl-paste <opts...>`

## Options

### `ClipboardSelectionOpts`

- `selection: "clipboard"|"primary"|nil`
  - `nil`/`"clipboard"` uses the default clipboard
  - `"primary"` sets `--primary`

### `ClipboardCopyOpts` (extends `ClipboardSelectionOpts`)

- `type: string?` — MIME type (`--type <mime>`)
- `foreground: boolean?` — `--foreground`
- `paste_once: boolean?` — `--paste-once`
- `clear: boolean?` — `--clear`
- `extra: string[]?` — extra argv appended

### `ClipboardPasteOpts` (extends `ClipboardSelectionOpts`)

- `type: string?` — MIME type (`--type <mime>`)
- `no_newline: boolean?` — `--no-newline`
- `extra: string[]?` — extra argv appended

## Examples

### Copy from stdin (default clipboard)

```lua
local Clipboard = require("wardlib.app.wlcopy").Clipboard

-- wl-copy
local cmd = Clipboard.copy()

-- Example (pseudo; feeding stdin depends on your Ward build):
-- cmd:stdin("hello\n"):run()
```

### Copy to primary selection, set MIME type

```lua
local Clipboard = require("wardlib.app.wlcopy").Clipboard

-- wl-copy --primary --type text/plain
local cmd = Clipboard.copy({ selection = "primary", type = "text/plain" })
```

### Copy and keep wl-copy in foreground until paste

```lua
local Clipboard = require("wardlib.app.wlcopy").Clipboard

-- wl-copy --foreground
local cmd = Clipboard.copy({ foreground = true })
```

### Paste (no trailing newline)

```lua
local Clipboard = require("wardlib.app.wlcopy").Clipboard
local out = require("wardlib.tools.out")

-- wl-paste --no-newline
local text = out.cmd(Clipboard.paste({ no_newline = true }))
  :trim()
  :line()
```

### Clear selection

```lua
local Clipboard = require("wardlib.app.wlcopy").Clipboard

-- wl-copy --clear
local cmd = Clipboard.clear()

-- wl-copy --primary --clear
local cmd2 = Clipboard.clear({ selection = "primary" })
```

### Extra flags pass-through

```lua
local Clipboard = require("wardlib.app.wlcopy").Clipboard

-- Example: wl-paste --primary --type text/plain --watch
local cmd = Clipboard.paste({
  selection = "primary",
  type = "text/plain",
  extra = { "--watch" }, -- if supported by your wl-paste build
})
```
