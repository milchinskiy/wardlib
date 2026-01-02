# gsettings

## Read a key

```lua
local Gsettings = require("app.gsettings").Gsettings

-- Equivalent to: gsettings get org.gnome.desktop.interface clock-show-date
local cmd = Gsettings.get("org.gnome.desktop.interface", "clock-show-date")

-- Example: local v = cmd:output()
```

## Set a key

```lua
local Gsettings = require("app.gsettings").Gsettings

-- Equivalent to: gsettings set org.gnome.desktop.interface clock-show-date true
local cmd = Gsettings.set("org.gnome.desktop.interface", "clock-show-date", "true")
```

## Reset a key

```lua
local Gsettings = require("app.gsettings").Gsettings

-- Equivalent to: gsettings reset org.gnome.desktop.interface clock-show-date
local cmd = Gsettings.reset("org.gnome.desktop.interface", "clock-show-date")
```

## List keys for a schema

```lua
local Gsettings = require("app.gsettings").Gsettings

-- Equivalent to: gsettings list-keys org.gnome.desktop.interface
local cmd = Gsettings.list_keys("org.gnome.desktop.interface")
```

## List schemas / recursively dump values

```lua
local Gsettings = require("app.gsettings").Gsettings

-- Equivalent to: gsettings list-schemas
local cmd1 = Gsettings.list_schemas()

-- Equivalent to: gsettings list-recursively
local cmd2 = Gsettings.list_recursively()

-- Equivalent to: gsettings list-recursively org.gnome.desktop.interface
local cmd3 = Gsettings.list_recursively("org.gnome.desktop.interface")
```
