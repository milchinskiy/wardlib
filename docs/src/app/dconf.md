# dconf

`dconf` is a low-level configuration system used by many desktop components
(notably GNOME).

> This module constructs `ward.process.cmd(...)` invocations; it does not parse output.
> consumers can use `wardlib.tools.out` (or their own parsing) on the `:output()`
> result.

## Import

```lua
local Dconf = require("wardlib.app.dconf").Dconf
```

## Notes

- Keys must start with `/` and must **not** end with `/`.
- Directories must start with `/` and must **end** with `/`.
- `Dconf.write(...)` encodes common Lua values into GVariant literals;
for complex values, use `Dconf.raw("<gvariant>")`.

## API

### `Dconf.raw(value)`

Marks a raw GVariant literal that will be passed through without encoding.

### `Dconf.encode(value)`

Encodes common Lua primitives into GVariant literals:

- `string` -> quoted string (single quotes with minimal escaping)
- `boolean` -> `true`/`false`
- `number` -> number literal
- `Dconf.raw(...)` -> passed through as-is

### `Dconf.read(key)`

Builds: `dconf read <key>`

### `Dconf.write(key, value)`

Builds: `dconf write <key> <gvariant>`

### `Dconf.reset(key_or_dir, opts)`

Builds: `dconf reset [-f] <path>`

If `opts.force=true`, the `path` must be a directory (end with `/`).

### `Dconf.list(dir)`

Builds: `dconf list <dir>`

### `Dconf.dump(dir)`

Builds: `dconf dump <dir>`

### `Dconf.load(dir, data)`

Builds: `dconf load <dir>`

If `data` is provided, it is attached as stdin when possible.

All functions return a `ward.process.cmd(...)` object.

## Examples

### Read and parse a value

```lua
local Dconf = require("wardlib.app.dconf").Dconf
local out = require("wardlib.tools.out")

local res = Dconf.read("/org/gnome/desktop/interface/gtk-theme"):output()
local value = out.res(res):label("dconf read gtk-theme"):trim():line()
-- value is a GVariant literal, e.g. 'Adwaita-dark'
```

### Write a string (auto-encoding)

```lua
local Dconf = require("wardlib.app.dconf").Dconf

-- dconf write /org/gnome/desktop/interface/gtk-theme 'Adwaita-dark'
Dconf.write("/org/gnome/desktop/interface/gtk-theme", "Adwaita-dark"):run()
```

### Write a raw GVariant literal

```lua
local Dconf = require("wardlib.app.dconf").Dconf

-- dconf write /org/example/raw [1, 2, 3]
Dconf.write("/org/example/raw", Dconf.raw("[1, 2, 3]")):run()
```

### Reset a subtree

```lua
local Dconf = require("wardlib.app.dconf").Dconf

-- dconf reset -f /org/example/
Dconf.reset("/org/example/", { force = true }):run()
```

### Dump and restore

```lua
local Dconf = require("wardlib.app.dconf").Dconf
local out = require("wardlib.tools.out")

local dump = out.cmd(Dconf.dump("/org/example/")):label("dconf dump"):text()

-- Load back (stdin)
Dconf.load("/org/example/", dump):run()
```
