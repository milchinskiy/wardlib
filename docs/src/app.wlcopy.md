# wl-copy / wl-paste

## Copy from stdin (default clipboard)

```lua
local Clipboard = require("app.wlcopy").Clipboard
-- Equivalent to: wl-copy
local cmd = Clipboard.copy()
-- Example (pseudo): cmd:stdin("hello\n"):run()
```

## Copy to primary selection, set MIME type

```lua
local Clipboard = require("app.wlcopy").Clipboard

-- Equivalent to: wl-copy --primary --type text/plain
local cmd = Clipboard.copy({
  selection = "primary",
  type = "text/plain",
})
```

## Copy and keep wl-copy in foreground until paste (useful for some apps)

```lua
local Clipboard = require("app.wlcopy").Clipboard
-- Equivalent to: wl-copy --foreground
local cmd = Clipboard.copy({ foreground = true })
```

## Paste (no trailing newline)

```lua
local Clipboard = require("app.wlcopy").Clipboard

-- Equivalent to: wl-paste --no-newline
local cmd = Clipboard.paste({ no_newline = true })

-- Example: local text = cmd:output()
```

## Clear selection

```lua
local Clipboard = require("app.wlcopy").Clipboard

-- Equivalent to: wl-copy --clear
local cmd = Clipboard.clear()

-- Clear primary:
-- Equivalent to: wl-copy --primary --clear
local cmd2 = Clipboard.clear({ selection = "primary" })
```

## Extra flags pass-through

```lua
local Clipboard = require("app.wlcopy").Clipboard

-- Example: wl-paste --primary --type text/plain
-- but with an extra flag appended
local cmd = Clipboard.paste({
  selection = "primary",
  type = "text/plain",
  extra = { "--watch" }, -- if supported by your wl-paste build
})
```
