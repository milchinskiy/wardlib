# DConf

Examples:

```lua
local Dconf = require("app.dconf").Dconf

-- Read a key
local cmd1 = Dconf.read("/org/gnome/desktop/interface/gtk-theme")

-- Write a string (auto-encoded to GVariant: 'Adwaita-dark')
local cmd2 = Dconf.write("/org/gnome/desktop/interface/gtk-theme", "Adwaita-dark")

-- Write a raw GVariant literal (you provide full syntax)
local cmd3 = Dconf.write("/org/example/raw", Dconf.raw("[1, 2, 3]"))

-- Reset a single key
local cmd4 = Dconf.reset("/org/example/key")

-- Reset a subtree (recursive)
local cmd5 = Dconf.reset("/org/example/", { force = true })

-- Dump / load (dir must end with '/')
local cmd6 = Dconf.dump("/org/example/")
local cmd7 = Dconf.load("/org/example/", "[section]\nkey='x'\n")
```
