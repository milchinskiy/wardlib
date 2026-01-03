# cfdisk

## Interactive partition editing

```lua
local Cfdisk = require("app.cfdisk").Cfdisk

-- Equivalent to: cfdisk /dev/sda
Cfdisk.edit("/dev/sda"):run()
```

## With modeled options + pass-through flags

```lua
local Cfdisk = require("app.cfdisk").Cfdisk

-- Equivalent to:
--   cfdisk --color=never --sector-size 4096 --read-only --zero --wipe always /dev/sda
Cfdisk.edit("/dev/sda", {
  color = "never",
  sector_size = 4096,
  read_only = true,
  zero = true,
  extra = { "--wipe", "always" }, -- anything not modeled
}):run()
```

## JSON

```lua
local Sfdisk = require("app.cfdisk").Sfdisk

-- Equivalent to: sfdisk --json /dev/nvme0n1
Sfdisk.json("/dev/nvme0n1"):output()
```
