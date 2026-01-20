# dunst

`dunstify` is a CLI client for the Dunst notification daemon.

> This module constructs `ward.process.cmd(...)` invocations; it does not parse output.
> consumers can use `wardlib.tools.out` (or their own parsing) on the `:output()`
> result.

## Import

```lua
local Dunst = require("wardlib.app.dunst").Dunst
```

## API

### `Dunst.notify(summary, opts)`

Builds: `dunstify <opts...> <summary> [body]`

- `summary`: notification title/summary
- `opts.body`: optional body text (appended as a positional argument)

### `Dunst.close(id)`

Builds: `dunstify -C <id>`

### `Dunst.capabilities()`

Builds: `dunstify --capabilities`

### `Dunst.serverInfo()`

Builds: `dunstify --serverinfo`

All functions return a `ward.process.cmd(...)` object.

## Options (`DunstifyOptions`)

- Content: `body`
- App identity: `app_name` (`-a <name>`)
- Urgency: `urgency` (`-u low|normal|critical`)
- Timeout: `timeout` (`-t <ms>`)
- Replace: `replaceId` (`-r <id>`)
- Hints: `hints` (`-h <hint>`)
- Actions: `action` (`-A <action>`)
- Icons: `icon` (`-i <icon>`), `raw_icon` (`-I <path>`)
- Category: `category` (`-c <category>`)
- Interaction: `block` (`-b`) waits for a user action
- Output: `printId` (`-p`) prints notification id to stdout

## Examples

```lua
local Dunst = require("wardlib.app.dunst").Dunst
local out = require("wardlib.tools.out")

-- Simple notification
Dunst.notify("Hello", { body = "World" }):run()

-- Notification that prints its id
local res = Dunst.notify("Build", {
  body = "Finished",
  urgency = "normal",
  timeout = 2000,
  printId = true,
}):output()

local id = tonumber(out.res(res):label("dunstify -p"):trim():line())

-- Close it later
Dunst.close(id):run()

-- Inspect server info / capabilities
local caps = out.cmd(Dunst.capabilities()):label("dunstify --capabilities"):lines()
local info = out.cmd(Dunst.serverInfo()):label("dunstify --serverinfo"):text()
```
