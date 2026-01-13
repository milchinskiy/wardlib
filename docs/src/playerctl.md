# playerctl

## Control a specific player

```lua
local Playerctl = require("wardlib.app.playerctl").Playerctl

-- Equivalent to: playerctl --player spotify play-pause
local cmd = Playerctl.play_pause({ player = "spotify" })
```

## Next / previous across all players

```lua
local Playerctl = require("wardlib.app.playerctl").Playerctl

-- Equivalent to: playerctl --all-players next
local next_cmd = Playerctl.next({ all_players = true })

-- Equivalent to: playerctl --all-players previous
local prev_cmd = Playerctl.previous({ all_players = true })
```

## Ignore some players

```lua
local Playerctl = require("wardlib.app.playerctl").Playerctl

-- Equivalent to: playerctl --all-players --ignore-player firefox \
--                  --ignore-player chromium status
local cmd = Playerctl.status({
  all_players = true,
  ignore = { "firefox", "chromium" },
})
```

## Read status

```lua
local Playerctl = require("wardlib.app.playerctl").Playerctl

-- Equivalent to: playerctl status
local cmd = Playerctl.status()

-- Example: local st = cmd:output()
```

## Read metadata with a format string

```lua
local Playerctl = require("wardlib.app.playerctl").Playerctl

-- Equivalent to:
-- playerctl --player spotify metadata --format "{{artist}} - {{title}}"
local cmd = Playerctl.metadata({
  player = "spotify",
  format = "{{artist}} - {{title}}",
})

-- Example: local line = cmd:output()
```

## Advanced flags via `extra`

```lua
local Playerctl = require("wardlib.app.playerctl").Playerctl

-- Equivalent to: playerctl --player spotify --follow status
local cmd = Playerctl.status({
  player = "spotify",
  extra = { "--follow" },
})
```
