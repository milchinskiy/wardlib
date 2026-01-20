# blkid

`blkid` prints block device attributes (LABEL, UUID, TYPE, etc.).

> This module constructs `ward.process.cmd(...)` invocations; it does not parse output.
> consumers can use `wardlib.tools.out` (or their own parsing) on the `:output()`
> result.

## Import

```lua
local Blkid = require("wardlib.app.blkid").Blkid
```

## Privilege escalation

Depending on your system configuration, probing certain devices may require
elevated privileges. This module does not implement `sudo`/`doas` options;
use `wardlib.tools.with` middleware.

```lua
local w = require("wardlib.tools.with")
local Blkid = require("wardlib.app.blkid").Blkid

w.with(w.middleware.sudo(), Blkid.id("/dev/sda1")):run()
```

## API

### `Blkid.bin`

Executable name or path used for `blkid`.

### `Blkid.id(devices, opts)`

Builds: `blkid <opts...> [devices...]`

- `devices: string|string[]|nil` — one or more device paths. When `nil`,
`blkid` probes available devices.
- `opts: BlkidOpts|nil` — modeled options.

### `Blkid.by_label(label)`

Builds: `blkid -L <label>`

### `Blkid.by_uuid(uuid)`

Builds: `blkid -U <uuid>`

## Options (`BlkidOpts`)

- `output: "full"|"value"|"device"|"export"|"udev"|nil` — `-o <fmt>`.
- `tags: string[]|nil` — `-s <tag>` repeated (e.g. `{ "UUID", "TYPE" }`).
- `match: string|string[]|nil` — `-t <token>` repeated (e.g. `"TYPE=ext4"`).
- `cache_file: string|nil` — `-c <file>` (use `"/dev/null"` to disable cache).
- `probe: boolean|nil` — `-p` (low-level probe).
- `wipe_cache: boolean|nil` — `-w` / `--wipe-cache`.
- `garbage_collect: boolean|nil` — `-g` / `--garbage-collect`.
- `extra: string[]|nil` — pass-through args appended after modeled options.

## Examples

### Probe a device and print selected fields

```lua
local Blkid = require("wardlib.app.blkid").Blkid

-- blkid -o export -s UUID -s TYPE /dev/sda1
local cmd = Blkid.id("/dev/sda1", {
  output = "export",
  tags = { "UUID", "TYPE" },
})
```

### Find the device path by label or UUID

```lua
local Blkid = require("wardlib.app.blkid").Blkid

-- blkid -L root
local by_label = Blkid.by_label("root")

-- blkid -U 1111-2222
local by_uuid = Blkid.by_uuid("1111-2222")
```

### Filter by token match

```lua
local Blkid = require("wardlib.app.blkid").Blkid

-- blkid -t TYPE=ext4 -t LABEL=myroot
local cmd = Blkid.id(nil, {
  match = { "TYPE=ext4", "LABEL=myroot" },
})
```

### Parse `-o export` output

```lua
local Blkid = require("wardlib.app.blkid").Blkid
local out = require("wardlib.tools.out")

local res = Blkid.id("/dev/sda1", { output = "export" }):output()
local kv = {}
for _, line in ipairs(out.res(res):ok():lines()) do
  local k, v = line:match("^([^=]+)=(.*)$")
  if k ~= nil then kv[k] = v end
end

-- kv.UUID, kv.TYPE, ...
```
