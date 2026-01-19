# lsblk

`lsblk` lists block devices and their topology.

The wrapper constructs a `ward.process.cmd(...)` invocation; it does not parse output.

## List all devices as JSON

```lua
local Lsblk = require("wardlib.app.lsblk").Lsblk

-- Equivalent to: lsblk -J -b
local cmd = Lsblk.list(nil, { json = true, bytes = true })

-- local out = cmd:output()
```

## List selected columns for a specific device

```lua
local Lsblk = require("wardlib.app.lsblk").Lsblk

-- Equivalent to: lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT /dev/sda
local cmd = Lsblk.list("/dev/sda", {
  output = { "NAME", "SIZE", "FSTYPE", "MOUNTPOINT" },
})
```

## Raw, no headings (useful for scripts)

```lua
local Lsblk = require("wardlib.app.lsblk").Lsblk

-- Equivalent to: lsblk -r -n -o NAME,TYPE /dev/sda
local cmd = Lsblk.list("/dev/sda", {
  raw = true,
  noheadings = true,
  output = { "NAME", "TYPE" },
})
```

## Use an explicit lsblk binary

```lua
local Lsblk = require("wardlib.app.lsblk").Lsblk
Lsblk.bin = "/usr/bin/lsblk"

local cmd = Lsblk.list(nil, { list = true })
```
