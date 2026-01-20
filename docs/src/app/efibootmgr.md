# efibootmgr

Thin wrapper around `efibootmgr` (UEFI Boot Manager configuration).

> This module constructs `ward.process.cmd(...)` invocations; it does not parse output.
> consumers can use `wardlib.tools.out` (or their own parsing) on the `:output()`
> result.

This module intentionally models only the most common flags;
use `opts.extra` for everything else.

## Import

```lua
local E = require("wardlib.app.efibootmgr").Efibootmgr
```

## Running with elevated privileges

Most `efibootmgr` operations require root. Use `wardlib.tools.with` middleware:

```lua
local with = require("wardlib.tools.with")
local E = require("wardlib.app.efibootmgr").Efibootmgr

with.with(with.middleware.sudo(), function()
  E.list({ verbose = true }):run()
end)
```

## API

### `E.cmd(opts)`

Builds: `efibootmgr <opts...>`

### `E.list(opts)`

Alias for `E.cmd(opts)`.

### `E.set_bootnext(bootnum, opts)` / `E.delete_bootnext(opts)`

Builds: `efibootmgr -n XXXX` and `efibootmgr -N`.

### `E.set_bootorder(order, opts)` / `E.delete_bootorder(opts)`

Builds: `efibootmgr -o 0001,0002,...` and `efibootmgr -O`.

### `E.set_timeout(seconds, opts)` / `E.delete_timeout(opts)`

Builds: `efibootmgr -t <seconds>` and `efibootmgr -T`.

### `E.delete(bootnum, opts)`

Builds: `efibootmgr -b XXXX -B`.

### `E.create_entry(opts)`

Convenience: sets `opts.create=true` and builds:

`efibootmgr -c -d <disk> -p <part> -l <loader> -L <label> ...`

All functions return a `ward.process.cmd(...)` object.

## Options (`EfibootmgrOpts`)

Common fields:

- Binary: `bin` (override executable name/path)
- Output: `verbose` (`-v`), `quiet` (`-q`)
- Entry selection: `bootnum` (`-b XXXX`) where `XXXX` is a 4-hex-digit boot number
- Entry state: `active` (`-a`), `inactive` (`-A`)
- Entry deletion: `delete_bootnum` (`-B`)
- Entry creation: `create` (`-c`), `create_only` (`-C`)
- Entry parameters: `disk` (`-d <disk>`), `part` (`-p <part>`),
`loader` (`-l <loader>`), `label` (`-L <label>`)
- One-time next boot: `bootnext` (`-n XXXX`), `delete_bootnext` (`-N`)
- Boot order: `bootorder` (`-o ...`), `delete_bootorder` (`-O`)
  - `bootorder` accepts a comma-separated string or an array of boot numbers.
- Timeout: `timeout` (`-t <sec>`), `delete_timeout` (`-T`)
- Other flags: `unicode` (`-u`), `write_signature` (`-w`), `remove_dups` (`-D`),
`driver` (`-r`), `sysprep` (`-y`)
- Device path flags: `full_dev_path` (`--full-dev-path`), `file_dev_path` (`--file-dev-path`)
- Append extra loader args: `append_binary_args`
(`-@ <file>`; use `-` to read from stdin)
- Escape hatch: `extra`

## Examples

### List current configuration

```lua
local with = require("wardlib.tools.with")
local E = require("wardlib.app.efibootmgr").Efibootmgr

with.with(with.middleware.sudo(), function()
  -- efibootmgr -v
  E.list({ verbose = true }):run()
end)
```

### Set BootNext (one-time next boot)

```lua
local with = require("wardlib.tools.with")
local E = require("wardlib.app.efibootmgr").Efibootmgr

with.with(with.middleware.sudo(), function()
  -- efibootmgr -n 0004
  E.set_bootnext(4):run()

  -- efibootmgr -N
  E.delete_bootnext():run()
end)
```

### Create a boot entry

```lua
local with = require("wardlib.tools.with")
local E = require("wardlib.app.efibootmgr").Efibootmgr

with.with(with.middleware.sudo(), function()
  E.create_entry({
    disk = "/dev/sda",
    part = 1,
    loader = "\\\\EFI\\\\Linux\\\\grubx64.efi",
    label = "Linux",
  }):run()
end)
```
