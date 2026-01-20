# sfdisk

`sfdisk` (from **util-linux**) is a script-oriented tool for partitioning block devices.

> This module constructs `ward.process.cmd(...)` invocations; it does not parse output.
> consumers can use `wardlib.tools.out` (or their own parsing) on the `:output()`
> result.
> It provides a small helper to build sfdisk scripts (`Sfdisk.script`) and a convenience
> pipeline builder (`Sfdisk.apply`).

## Import

```lua
local Sfdisk = require("wardlib.app.sfdisk").Sfdisk
```

## Privilege model

Partitioning requires elevated privileges on most systems. Prefer a **scoped** middleware
approach (instead of embedding `sudo` flags in wrappers):

```lua
local with = require("wardlib.tools.with")
local Sfdisk = require("wardlib.app.sfdisk").Sfdisk

with.with(with.middleware.sudo(), function()
  Sfdisk.list("/dev/sda"):run()
end)
```

## API

### `Sfdisk.bin`

Executable name or path (default: `"sfdisk"`).

### `Sfdisk.cmd(argv, opts)`

Builds: `sfdisk <opts...> [argv...]`

Generic escape hatch for constructing `sfdisk` invocations.

### `Sfdisk.dump(device, opts)`

Builds: `sfdisk --dump <device>`

### `Sfdisk.json(device, opts)`

Builds: `sfdisk --json <device>`

### `Sfdisk.list(device, opts)`

Builds: `sfdisk --list <device>`

### `Sfdisk.write(device, opts)`

Builds: `sfdisk <opts...> <device>`

Returns a command expecting the sfdisk script on stdin.

### `Sfdisk.script(spec)`

Encodes a structured `SfdiskTable` into an sfdisk script string.

### `Sfdisk.apply(device, spec_or_script, opts)`

Builds a pipeline:

- `printf "%s" <script> | sfdisk <opts...> <device>`

`spec_or_script` may be a raw string script or a structured `SfdiskTable`.

## Options

### `SfdiskOpts`

- `force: boolean?` → `--force`
- `no_reread: boolean?` → `--no-reread`
- `no_act: boolean?` → `--no-act`
- `quiet: boolean?` → `--quiet`
- `lock: boolean|"yes"|"no"|"nonblock"|nil` → `--lock[=mode]`
  - `true` / `"yes"` → `--lock`
  - `false` / `"no"` → `--lock=no`
  - `"nonblock"` → `--lock=nonblock`
- `wipe: "auto"|"never"|"always"|string|nil` → `--wipe <mode>`
- `label: string?` → `--label <type>` (e.g. `"gpt"`, `"dos"`)
- `sector_size: integer?` → `--sector-size <n>`
- `extra: string[]?` → extra argv inserted before positional args

## Script structures

### `SfdiskPartition`

Each partition line is rendered as comma-separated `key=value` fields.

- `start: string|integer|nil`
- `size: string|integer|nil`
- `type: string|nil`
- `uuid: string|nil`
- `name: string|nil`
- `attrs: string|nil`
- `bootable: boolean|nil` → emits `bootable`
- `extra: table<string, string|number|boolean>|nil` → appended at end
(sorted by key)

### `SfdiskTable`

Header fields are emitted as `key: value` lines.

- `label: string|nil`
- `label_id: string|nil` → `label-id:`
- `unit: string|nil` → `unit:` (e.g. `"sectors"`)
- `first_lba: integer|nil` → `first-lba:`
- `last_lba: integer|nil` → `last-lba:`
- `extra_header: table<string, string|number|boolean>|nil` → extra header lines (sorted)
- `partitions: SfdiskPartition[]` (required)

## Examples

### Dump and parse JSON output

```lua
local Sfdisk = require("wardlib.app.sfdisk").Sfdisk
local out = require("wardlib.tools.out")

local data = out.cmd(Sfdisk.json("/dev/sda"))
  :label("sfdisk --json /dev/sda")
  :json()

-- data.sfdisk is typically a table with disklabel/partitions information.
```

### Apply partitions via stdin in one call (raw script)

This matches: `printf "..." | sfdisk ...`.

```lua
local with = require("wardlib.tools.with")
local Sfdisk = require("wardlib.app.sfdisk").Sfdisk

local script = [[
label: gpt
unit: sectors

start=2048, size=1048576, type=U
start=1050624, size=20971520, type=8300
]]

with.with(with.middleware.sudo(), function()
  Sfdisk.apply("/dev/sda", script, { force = true }):run()
end)
```

### Apply partitions via a structured spec

```lua
local with = require("wardlib.tools.with")
local Sfdisk = require("wardlib.app.sfdisk").Sfdisk

local spec = {
  label = "gpt",
  unit = "sectors",
  partitions = {
    { start = 2048, size = "512M", type = "U" },
    { start = 1050624, size = "20G", type = "8300", bootable = true },
  },
}

with.with(with.middleware.sudo(), function()
  Sfdisk.apply("/dev/sda", spec, { force = true, wipe = "always" }):run()
end)
```

### Advanced flags and passthrough args

```lua
local with = require("wardlib.tools.with")
local Sfdisk = require("wardlib.app.sfdisk").Sfdisk

local spec = {
  label = "gpt",
  partitions = {
    { start = 2048, size = "1G", type = "U" },
    { start = 0, size = 0, type = "8300" },
  },
}

with.with(with.middleware.sudo(), function()
  Sfdisk.apply("/dev/sda", spec, {
    force = true,
    no_reread = true,
    lock = "nonblock",
    wipe = "always",
    sector_size = 4096,
    extra = { "--wipe-partitions", "always" },
  }):run()
end)
```
