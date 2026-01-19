# yay

`app.yay` is a thin wrapper around `yay` (AUR helper).

## System upgrade

```lua
local Yay = require("wardlib.app.yay").Yay

-- Equivalent to: yay -Syu
local cmd = Yay.upgrade()

-- Equivalent to: yay -Syyu (force refresh)
local refresh = Yay.upgrade({ refresh = true })
```

## Install packages (including AUR)

```lua
local Yay = require("wardlib.app.yay").Yay

-- Equivalent to: yay -S --needed --noconfirm google-chrome
local cmd = Yay.install("google-chrome", { needed = true, noconfirm = true })
```

## Search and remove

```lua
local Yay = require("wardlib.app.yay").Yay

-- Equivalent to: yay -Ss neovim
local search = Yay.search("neovim")

-- Equivalent to: yay -Rns neovim
local rm = Yay.remove("neovim", { recursive = true, nosave = true })
```
