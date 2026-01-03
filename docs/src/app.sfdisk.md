# sfdisk

## Dump

```lua
local Sfdisk = require("app.sfdisk").Sfdisk

-- Equivalent to: sfdisk --dump /dev/nvme0n1
local dump = Sfdisk.dump("/dev/nvme0n1")
local output = dump:output()
```

## List

```lua
local Sfdisk = require("app.sfdisk").Sfdisk

-- Equivalent to: sfdisk --list /dev/nvme0n1
Sfdisk.list("/dev/nvme0n1"):run()
```

## Apply partitions via stdin in one call (raw string)

This matches workflow: `printf "... \n ..." | sfdisk ...`

```lua
local Sfdisk = require("app.sfdisk").Sfdisk

local script = [[
label: gpt
unit: sectors

start=2048, size=1048576, type=U
start=1050624, size=20971520, type=8300
]]

-- Builds and runs: printf "%s" <script> | sfdisk --force /dev/sda
Sfdisk.apply("/dev/sda", script, { force = true }):run()
```

## Apply partitions via a structured "spec" table

```lua
local Sfdisk = require("app.sfdisk").Sfdisk

local spec = {
  label = "gpt",
  unit = "sectors",
  partitions = {
    { start = 2048, size = "512M", type = "U" },
    { start = 1050624, size = "20G", type = "8300", bootable = true },
  },
}

-- you can inspect spec with:
-- print(spec)

-- Builds: printf "%s" <rendered> | sfdisk --force /dev/sda
Sfdisk.apply("/dev/sda", spec, { force = true }):run()
```

## Advanced sfdisk flags + extra args

```lua
local Sfdisk = require("app.cfdisk").Sfdisk

local spec = {
  label = "gpt",
  partitions = {
    { start = 2048, size = "1G", type = "U" },
    { start = 0, size = "0", type = "8300" }, -- examples only; use correct values
  },
}

Sfdisk.apply("/dev/sda", spec, {
  force = true,
  no_reread = true,
  lock = "nonblock",
  wipe = "always",
  sector_size = 4096,
  extra = { "--wipe-partitions", "always" }, -- passthrough
}):run()
```
