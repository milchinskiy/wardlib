# playerctl

`playerctl` controls MPRIS-compatible media players (play/pause/next/status/metadata).

> This module constructs `ward.process.cmd(...)` invocations; it does not parse output.
> consumers can use `wardlib.tools.out` (or their own parsing) on the `:output()`
> result.

## Import

```lua
local Playerctl = require("wardlib.app.playerctl").Playerctl
```

## Privilege model

`playerctl` is a user-session tool. It typically runs **without** elevation. If your
Ward script runs as root (or inside a non-user environment), make sure the relevant
session bus is available.

## API

### `Playerctl.bin`

Executable name or path (default: `"playerctl"`).

### `Playerctl.cmd(subcmd, argv, opts)`

Builds: `playerctl <global-opts...> <subcmd> [argv...]`

Use this as an escape hatch for subcommands not covered by convenience helpers.

### Convenience commands

All of the following return a `ward.Cmd`:

- `Playerctl.play(opts)` → `playerctl ... play`
- `Playerctl.pause(opts)` → `playerctl ... pause`
- `Playerctl.play_pause(opts)` → `playerctl ... play-pause`
- `Playerctl.next(opts)` → `playerctl ... next`
- `Playerctl.previous(opts)` → `playerctl ... previous`
- `Playerctl.stop(opts)` → `playerctl ... stop`
- `Playerctl.status(opts)` → `playerctl ... status`

### `Playerctl.metadata(opts)`

Builds: `playerctl <global-opts...> metadata [--format <fmt>]`

Returns track metadata. If `opts.format` is provided, output is formatted by
playerctl and typically becomes a single line.

## Options

### `PlayerctlOpts`

- `player: string?` → `--player <name>`
- `all_players: boolean?` → `--all-players`
- `ignore: string[]?` → `--ignore-player <name>` (repeatable)
- `extra: string[]?` → extra argv appended **before** the subcommand

### `PlayerctlMetadataOpts`

Extends `PlayerctlOpts`:

- `format: string?` → `--format <fmt>`

## Examples

### Control a specific player

```lua
local Playerctl = require("wardlib.app.playerctl").Playerctl

-- playerctl --player spotify play-pause
local cmd = Playerctl.play_pause({ player = "spotify" })
cmd:run()
```

### Next / previous across all players

```lua
local Playerctl = require("wardlib.app.playerctl").Playerctl

Playerctl.next({ all_players = true }):run()
Playerctl.previous({ all_players = true }):run()
```

### Ignore some players

```lua
local Playerctl = require("wardlib.app.playerctl").Playerctl

-- playerctl --all-players --ignore-player firefox --ignore-player chromium status
local cmd = Playerctl.status({
  all_players = true,
  ignore = { "firefox", "chromium" },
})
cmd:run()
```

### Parse status (stdout)

```lua
local Playerctl = require("wardlib.app.playerctl").Playerctl
local out = require("wardlib.tools.out")

local status = out.cmd(Playerctl.status())
  :label("playerctl status")
  :trim()
  :line()

-- status is typically: "Playing", "Paused", or "Stopped"
```

### Read metadata with a format string

```lua
local Playerctl = require("wardlib.app.playerctl").Playerctl
local out = require("wardlib.tools.out")

local line = out.cmd(Playerctl.metadata({
  player = "spotify",
  format = "{{artist}} - {{title}}",
}))
  :label("playerctl metadata")
  :trim()
  :text()
```

### Advanced flags via `extra`

```lua
local Playerctl = require("wardlib.app.playerctl").Playerctl

-- playerctl --player spotify --follow status
local cmd = Playerctl.status({
  player = "spotify",
  extra = { "--follow" },
})

-- cmd:run() will stream until interrupted
```
