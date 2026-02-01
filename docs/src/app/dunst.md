# dunst

This module wraps two CLI tools used with the Dunst notification daemon:

- `dunstify` – send notifications (client)
- `dunstctl` – control a running `dunst` instance

> This module constructs `ward.process.cmd(...)` invocations; it does not parse output.
> consumers can use `wardlib.tools.out` (or their own parsing) on the `:output()`
> result.

## Import

```lua
local Dunst = require("wardlib.app.dunst").Dunst
local DunstCtl = require("wardlib.app.dunst").DunstCtl
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

### `DunstCtl.*` (dunstctl)

> These functions build `dunstctl <command> ...`.

- `DunstCtl.close()` → `dunstctl close`
- `DunstCtl.closeAll()` → `dunstctl close-all`
- `DunstCtl.context()` → `dunstctl context`
- `DunstCtl.historyPop([id])` → `dunstctl history-pop [id]`
- `DunstCtl.historyRm(id)` → `dunstctl history-rm <id>`
- `DunstCtl.historyClear()` → `dunstctl history-clear`
- `DunstCtl.isPaused()` → `dunstctl is-paused`
- `DunstCtl.setPaused(v)` → `dunstctl set-paused <true|false|toggle>`
  - `v` may be boolean (`true`/`false`) or a string (`"true"|"false"|"toggle"`)
- `DunstCtl.getPauseLevel()` → `dunstctl get-pause-level`
- `DunstCtl.setPauseLevel(level)` → `dunstctl set-pause-level <0..100>`
- `DunstCtl.count([scope])` → `dunstctl count [displayed|history|waiting]`
- `DunstCtl.action(notification_position)` → `dunstctl action <pos>`
- `DunstCtl.rule(rule_name, action)` → `dunstctl rule <name> <enable|disable|toggle>`
- `DunstCtl.rules([opts])` → `dunstctl rules [--json]`
  - `opts.json = true` adds `--json`
- `DunstCtl.reload([files])` → `dunstctl reload [dunstrc ...]`
  - `files` may be a string or `string[]`
- `DunstCtl.debug()` → `dunstctl debug`
- `DunstCtl.help()` → `dunstctl help`

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
local DunstCtl = require("wardlib.app.dunst").DunstCtl
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

-- Pause / resume notifications (dunstctl)
DunstCtl.setPaused(true):run()
-- ... later
DunstCtl.setPaused(false):run()

-- Query paused status
local paused = out.cmd(DunstCtl.isPaused()):label("dunstctl is-paused"):trim():text()
-- Typical output is "true" or "false" (depends on dunstctl version)

-- Pop last closed notification from history
DunstCtl.historyPop():run()

-- Reload config
DunstCtl.reload({ os.getenv("HOME") .. "/.config/dunst/dunstrc" }):run()
```
