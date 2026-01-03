# apt-get

`app.aptget` is a thin wrapper around Debian/Ubuntu's `apt-get`.

## Update repository indexes

```lua
local AptGet = require("app.aptget").AptGet

-- Equivalent to: sudo apt-get update
local cmd = AptGet.update({ sudo = true })
```

## Upgrade installed packages

```lua
local AptGet = require("app.aptget").AptGet

-- Equivalent to: sudo apt-get -y -qq upgrade
local cmd = AptGet.upgrade({ sudo = true, assume_yes = true, quiet = 2 })
```

## Install packages (no recommends)

```lua
local AptGet = require("app.aptget").AptGet

-- Equivalent to: sudo apt-get -y install --no-install-recommends curl git
local cmd = AptGet.install({ "curl", "git" }, {
  sudo = true,
  assume_yes = true,
  no_install_recommends = true,
})
```

## Remove and autoremove

```lua
local AptGet = require("app.aptget").AptGet

-- Equivalent to: sudo apt-get purge vim
local purge = AptGet.remove("vim", { sudo = true, purge = true })

-- Equivalent to: sudo apt-get -y autoremove
local autoremove = AptGet.autoremove({ sudo = true, assume_yes = true })
```
