# efibootmgr

Thin wrapper around `efibootmgr` (UEFI Boot Manager configuration).

This module intentionally models only the most common flags; use `opts.extra`
for everything else.

## List current configuration

```lua
local E = require("app.efibootmgr").Efibootmgr

-- efibootmgr
E.list():run()

-- efibootmgr -v
E.list({ verbose = true }):run()
```

## Set BootNext (one-time next boot)

```lua
local E = require("app.efibootmgr").Efibootmgr

-- efibootmgr -n 0004
E.set_bootnext(4):run()

-- efibootmgr -N
E.delete_bootnext():run()
```

## Set BootOrder

```lua
local E = require("app.efibootmgr").Efibootmgr

-- efibootmgr -o 0003,0004,0001
E.set_bootorder({ 3, 4, 1 }):run()

-- efibootmgr -O
E.delete_bootorder():run()
```

## Set Timeout

```lua
local E = require("app.efibootmgr").Efibootmgr

-- efibootmgr -t 5
E.set_timeout(5):run()

-- efibootmgr -T
E.delete_timeout():run()
```

## Delete a boot entry

```lua
local E = require("app.efibootmgr").Efibootmgr

-- efibootmgr -b 0004 -B
E.delete(4):run()
```

## Create a boot entry

```lua
local E = require("app.efibootmgr").Efibootmgr

-- Equivalent to (example):
--   efibootmgr -c -d /dev/sda -p 1 -l "\\EFI\\Linux\\grubx64.efi" -L "Linux"
E.create_entry({
  disk = "/dev/sda",
  part = 1,
  loader = "\\EFI\\Linux\\grubx64.efi",
  label = "Linux",
}):run()
```

## Append loader arguments from a file (or stdin)

`efibootmgr` supports appending binary/extra loader arguments from a file via
`-@ <file>`, where `<file>` can be `-` to read from stdin.

```lua
local E = require("app.efibootmgr").Efibootmgr

-- Read extra args from stdin:
--   printf '...binary or text...' | efibootmgr -c ... -@ -
--
-- In ward, you can do the same by providing `append_binary_args = "-"` and
-- building your own pipeline.
E.create_entry({
  disk = "/dev/sda",
  part = 1,
  loader = "\\EFI\\Linux\\grubx64.efi",
  label = "Linux",
  append_binary_args = "-",
  unicode = true,
}):run()
```
