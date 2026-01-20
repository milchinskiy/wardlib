# Systemd

`wardlib.app.systemd` is a thin wrapper around `systemctl` and `journalctl`.
It returns `ward.process.cmd(...)` objects.

For predictable parsing of stdout/stderr, use [`wardlib.tools.out`](../tools/out.md).

## Basic operations

```lua
local Systemd = require("wardlib.app.systemd").Systemd

-- systemctl restart nginx.service
Systemd.restart("nginx.service")

-- systemctl --user enable --now syncthing.service
Systemd.enable("syncthing.service", { user = true, now = true })

-- journalctl -u nginx.service -f -n 200
Systemd.journal("nginx.service", { follow = true, lines = 200, since = "yesterday" })
```

## Query unit state (stdout parsing)

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

## Journal as JSON Lines

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

## Wait until a unit becomes active

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
