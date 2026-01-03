# pacman

`app.pacman` is a thin wrapper around Arch's `pacman`.

## Sync package databases

```lua
local Pacman = require("app.pacman").Pacman

-- Equivalent to: sudo pacman -Sy
local cmd = Pacman.sync({ sudo = true })

-- Equivalent to: sudo pacman -Syy (force refresh)
local refresh = Pacman.sync({ sudo = true, refresh = true })
```

## System upgrade

```lua
local Pacman = require("app.pacman").Pacman

-- Equivalent to: sudo pacman -Syu --noconfirm
local cmd = Pacman.upgrade({ sudo = true, noconfirm = true })
```

## Install and remove packages

```lua
local Pacman = require("app.pacman").Pacman

-- Equivalent to: sudo pacman -S --needed --noconfirm curl git
local install = Pacman.install({ "curl", "git" }, {
  sudo = true,
  needed = true,
  noconfirm = true,
})

-- Equivalent to: sudo pacman -Rns --noconfirm curl git
local remove = Pacman.remove({ "curl", "git" }, {
  sudo = true,
  recursive = true,
  nosave = true,
  noconfirm = true,
})
```

## Search and info

```lua
local Pacman = require("app.pacman").Pacman

-- Equivalent to: pacman -Ss lua
local search = Pacman.search("lua")

-- Equivalent to: pacman -Qi curl
local info = Pacman.info("curl")
```
