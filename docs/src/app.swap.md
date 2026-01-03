# swap

Wrappers around Linux swap tooling:

- `mkswap` — initialize a swap area
- `swapon` — enable swap
- `swapoff` — disable swap

The wrappers construct a `ward.process.cmd(...)` invocation; they do not parse output.

## Create swap on a file

```lua
local Swap = require("app.swap").Swap

-- Example flow (commands shown; file allocation is handled elsewhere)
-- mkswap -f -L swap0 /swapfile
local mk = Swap.mkswap("/swapfile", { force = true, label = "swap0" })

-- swapon /swapfile
local on = Swap.swapon("/swapfile")

-- swapoff /swapfile
local off = Swap.swapoff("/swapfile")
```

## Show active swaps

```lua
local Swap = require("app.swap").Swap

-- Equivalent to: swapon --show --noheadings --output NAME,SIZE,USED,PRIO
local cmd = Swap.status({
  noheadings = true,
  output = { "NAME", "SIZE", "USED", "PRIO" },
})
```

## Enable all swaps from /etc/fstab

```lua
local Swap = require("app.swap").Swap

-- Equivalent to: swapon -a
local cmd = Swap.swapon(nil, { all = true })
```

## Disable all swaps

```lua
local Swap = require("app.swap").Swap

-- Equivalent to: swapoff -a
local cmd = Swap.disable_all()
```
