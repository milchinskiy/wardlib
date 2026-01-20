# gsettings

`gsettings` is a CLI for reading and writing GSettings keys
(commonly used by GNOME and related components).

> This module constructs `ward.process.cmd(...)` invocations; it does not parse output.
> consumers can use `wardlib.tools.out` (or their own parsing) on the `:output()`
> result.

## Import

```lua
local Gsettings = require("wardlib.app.gsettings").Gsettings
```

## API

### `Gsettings.get(schema, key)`

Builds: `gsettings get <schema> <key>`

### `Gsettings.set(schema, key, value)`

Builds: `gsettings set <schema> <key> <value>`

The `value` is passed verbatim. Provide a valid GVariant string for the target type.

### `Gsettings.reset(schema, key)`

Builds: `gsettings reset <schema> <key>`

### `Gsettings.list_keys(schema)`

Builds: `gsettings list-keys <schema>`

### `Gsettings.list_schemas()`

Builds: `gsettings list-schemas`

### `Gsettings.list_recursively(schema_or_path)`

Builds: `gsettings list-recursively [schema_or_path]`

All functions return a `ward.process.cmd(...)` object.

## Examples

### Read a key

```lua
local Gsettings = require("wardlib.app.gsettings").Gsettings
local out = require("wardlib.tools.out")

-- gsettings get org.gnome.desktop.interface clock-show-date
local res = Gsettings.get("org.gnome.desktop.interface", "clock-show-date"):output()
local v = out.res(res):label("gsettings get"):trim():line()
-- Example output: true
```

### Set a key

```lua
local Gsettings = require("wardlib.app.gsettings").Gsettings

-- gsettings set org.gnome.desktop.interface clock-show-date true
Gsettings.set("org.gnome.desktop.interface", "clock-show-date", "true"):run()
```

### Reset a key

```lua
local Gsettings = require("wardlib.app.gsettings").Gsettings

-- gsettings reset org.gnome.desktop.interface clock-show-date
Gsettings.reset("org.gnome.desktop.interface", "clock-show-date"):run()
```

### List keys for a schema

```lua
local Gsettings = require("wardlib.app.gsettings").Gsettings
local out = require("wardlib.tools.out")

-- gsettings list-keys org.gnome.desktop.interface
local keys = out.cmd(Gsettings.list_keys("org.gnome.desktop.interface"))
  :label("gsettings list-keys")
  :lines()
```

### List schemas / recursively dump values

```lua
local Gsettings = require("wardlib.app.gsettings").Gsettings

-- gsettings list-schemas
local cmd1 = Gsettings.list_schemas()

-- gsettings list-recursively
local cmd2 = Gsettings.list_recursively()

-- gsettings list-recursively org.gnome.desktop.interface
local cmd3 = Gsettings.list_recursively("org.gnome.desktop.interface")
```
