# xbps

`app.xbps` is a thin wrapper around Void Linux's XBPS tooling (`xbps-install`, `xbps-remove`, `xbps-query`).

## Sync repositories

```lua
local Xbps = require("wardlib.app.xbps").Xbps

-- Equivalent to: sudo xbps-install -S
local cmd = Xbps.sync({ sudo = true })
```

## Full system upgrade (non-interactive)

```lua
local Xbps = require("wardlib.app.xbps").Xbps

-- Equivalent to: sudo xbps-install -y -Su
local cmd = Xbps.upgrade({ sudo = true, yes = true })
```

## Install packages

```lua
local Xbps = require("wardlib.app.xbps").Xbps

-- Equivalent to: sudo xbps-install -y curl git
local cmd = Xbps.install({ "curl", "git" }, { sudo = true, yes = true })
```

## Remove packages recursively

```lua
local Xbps = require("wardlib.app.xbps").Xbps

-- Equivalent to: sudo xbps-remove -y -R curl git
local cmd = Xbps.remove({ "curl", "git" }, { sudo = true, yes = true, recursive = true })
```

## Search repositories

```lua
local Xbps = require("wardlib.app.xbps").Xbps

-- Equivalent to: xbps-query --regex -Rs '^lua'
local cmd = Xbps.search("^lua", { regex = true })
```

## Inspect and list installed

```lua
local Xbps = require("wardlib.app.xbps").Xbps

-- Equivalent to: xbps-query -S curl
local info = Xbps.info("curl")

-- Equivalent to: xbps-query -l
local list = Xbps.list_installed()
```
