# apk

`app.apk` is a thin wrapper around Alpine's `apk`.

## Update repository indexes

```lua
local Apk = require("wardlib.app.apk").Apk

-- Equivalent to: apk update
local cmd = Apk.update()
```

## Upgrade installed packages

```lua
local Apk = require("wardlib.app.apk").Apk

-- Equivalent to: sudo apk upgrade
local cmd = Apk.upgrade({ sudo = true })
```

## Install packages (no cache)

```lua
local Apk = require("wardlib.app.apk").Apk

-- Equivalent to: sudo apk add --no-cache curl git
local cmd = Apk.add({ "curl", "git" }, { sudo = true, no_cache = true })
```

## Remove packages

```lua
local Apk = require("wardlib.app.apk").Apk

-- Equivalent to: sudo apk del curl git
local cmd = Apk.del({ "curl", "git" }, { sudo = true })
```

## Search and inspect

```lua
local Apk = require("wardlib.app.apk").Apk

-- Equivalent to: apk search curl
local search = Apk.search("curl")

-- Equivalent to: apk info curl
local info = Apk.info("curl")
```
