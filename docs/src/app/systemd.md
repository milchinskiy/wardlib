# Systemd

Examples:

```lua
local Systemd = require("wardlib.app.systemd").Systemd

Systemd.restart("nginx.service")
Systemd.enable("syncthing.service", { user = true, now = true })
Systemd.journal("nginx.service", { follow = true, lines = 200, since = "yesterday" })
```
