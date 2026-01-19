# blkid

`blkid` prints block device attributes (LABEL, UUID, TYPE, etc.).

The wrapper constructs a `ward.process.cmd(...)` invocation; it does not parse output.

## Probe a device and print selected fields

```lua
local Blkid = require("wardlib.app.blkid").Blkid

-- Equivalent to: blkid -o export -s UUID -s TYPE /dev/sda1
local cmd = Blkid.id("/dev/sda1", {
  output = "export",
  tags = { "UUID", "TYPE" },
})
```

## Find the device path by label or UUID

```lua
local Blkid = require("wardlib.app.blkid").Blkid

-- Equivalent to: blkid -L root
local cmd = Blkid.by_label("root")

-- Equivalent to: blkid -U 1111-2222
local cmd2 = Blkid.by_uuid("1111-2222")
```

## Filter by token match

```lua
local Blkid = require("wardlib.app.blkid").Blkid

-- Equivalent to: blkid -t TYPE=ext4 -t LABEL=myroot
local cmd = Blkid.id(nil, {
  match = { "TYPE=ext4", "LABEL=myroot" },
})
```
