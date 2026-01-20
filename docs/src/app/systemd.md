# systemd

`wardlib.app.systemd` is a thin wrapper around:

- `systemctl`
- `journalctl`

It returns `ward.process.cmd(...)` objects.

> This module constructs `ward.process.cmd(...)` invocations; it does not parse output.
> consumers can use `wardlib.tools.out` (or their own parsing) on the `:output()`
> result.

For predictable parsing of stdout/stderr, use [`wardlib.tools.out`](../tools/out.md).
For scoped privilege escalation, use [`wardlib.tools.with`](../tools/with.md).

## Import

```lua
local Systemd = require("wardlib.app.systemd").Systemd
```

## API

### `Systemd.start(unit, opts)`

Builds: `systemctl [--user] start <unit>`

### `Systemd.stop(unit, opts)`

Builds: `systemctl [--user] stop <unit>`

### `Systemd.restart(unit, opts)`

Builds: `systemctl [--user] restart <unit>`

### `Systemd.reload(unit, opts)`

Builds: `systemctl [--user] reload <unit>`

### `Systemd.enable(unit, opts)`

Builds: `systemctl [--user] enable [--now] <unit>`

### `Systemd.disable(unit, opts)`

Builds: `systemctl [--user] disable [--now] <unit>`

### `Systemd.is_active(unit, opts)`

Builds: `systemctl [--user] is-active <unit>`

### `Systemd.is_enabled(unit, opts)`

Builds: `systemctl [--user] is-enabled <unit>`

### `Systemd.status(unit, opts)`

Builds: `systemctl [--user] status [--no-pager] [--full] <unit>`

Note: `opts.no_pager` defaults to `true`.

### `Systemd.daemon_reload(opts)`

Builds: `systemctl [--user] daemon-reload`

### `Systemd.journal(unit, opts)`

Builds: `journalctl [--user] [--no-pager] [-u <unit>] [-f] [-n <lines>] [--since <time>] [--until <time>] [-p <prio>] [-o <format>]`

Note: `opts.no_pager` defaults to `true`.

## Options

### `SystemdCommonOpts`

- `user: boolean?` — use per-user manager (`--user`)

### `SystemdEnableDisableOpts` (extends `SystemdCommonOpts`)

- `now: boolean?` — start/stop unit immediately (`--now`)

### `SystemdStatusOpts` (extends `SystemdCommonOpts`)

- `no_pager: boolean?` — `--no-pager` (defaults to `true`)
- `full: boolean?` — `--full`

### `SystemdJournalOpts` (extends `SystemdCommonOpts`)

- `follow: boolean?` — `-f`
- `lines: integer?` — `-n <lines>`
- `since: string?` — `--since <time>`
- `until: string?` — `--until <time>`
- `priority: string?` — `-p <prio>` (e.g. `"err"`, `"warning"`, `"info"`, `"3"`)
- `no_pager: boolean?` — `--no-pager` (defaults to `true`)
- `output: string?` — `-o <format>` (e.g. `"short-iso"`, `"cat"`, `"json"`)

## Examples

### Basic operations

```lua
local Systemd = require("wardlib.app.systemd").Systemd

-- systemctl restart nginx.service
Systemd.restart("nginx.service")

-- systemctl --user enable --now syncthing.service
Systemd.enable("syncthing.service", { user = true, now = true })

-- journalctl -u nginx.service -f -n 200
Systemd.journal("nginx.service", { follow = true, lines = 200, since = "yesterday" })
```

### Running system service operations under sudo

```lua
local Systemd = require("wardlib.app.systemd").Systemd
local w = require("wardlib.tools.with")

w.with(w.middleware.sudo(), function()
  Systemd.daemon_reload():run()
  Systemd.restart("nginx.service"):run()
end)
```

### Query unit state (stdout parsing)

`systemctl is-active` and `is-enabled` encode state in both stdout and exit code.
A common pattern is to allow non-zero exit codes and parse the single-line output.

```lua
local Systemd = require("wardlib.app.systemd").Systemd
local out = require("wardlib.tools.out")

local active_state = out.cmd(Systemd.is_active("nginx.service"))
  :label("systemctl is-active nginx.service")
  :allow_fail()
  :trim()
  :line()

-- Examples: "active", "inactive", "failed", ...

local enabled_state = out.cmd(Systemd.is_enabled("nginx.service"))
  :label("systemctl is-enabled nginx.service")
  :allow_fail()
  :trim()
  :line()

-- Examples: "enabled", "disabled", "static", ...
```

### Journal as JSON Lines

`journalctl -o json` emits one JSON object per line (NDJSON). Use `out:json_lines()`.

```lua
local Systemd = require("wardlib.app.systemd").Systemd
local out = require("wardlib.tools.out")

local entries = out.cmd(Systemd.journal("nginx.service", { output = "json", lines = 50 }))
  :label("journalctl -u nginx.service -o json -n 50")
  :json_lines()

-- Each entry is a decoded Lua table. For example:
-- for _, e in ipairs(entries) do print(e.MESSAGE) end
```

### Wait until a unit becomes active

Combine `wardlib.tools.retry` with `systemctl is-active` parsing.

```lua
local Systemd = require("wardlib.app.systemd").Systemd
local out = require("wardlib.tools.out")
local retry = require("wardlib.tools.retry")

retry.try(function()
  local state = out.cmd(Systemd.is_active("nginx.service"))
    :allow_fail()
    :trim()
    :line()

  if state ~= "active" then
    error("nginx.service is not active yet: " .. state)
  end
end, { retries = 30, delay = 0.5 })
```
