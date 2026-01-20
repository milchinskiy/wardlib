# app.lsblk

`app.lsblk` is a thin command-construction wrapper around the util-linux
`lsblk` binary. It returns `ward.process.cmd(...)` objects.

`lsblk` supports JSON output (`-J`), and this wrapper models that flag.

> This module constructs `ward.process.cmd(...)` invocations; it does not parse output.
> consumers can use `wardlib.tools.out` (or their own parsing) on the `:output()`
> result.

## Import

```lua
local Lsblk = require("wardlib.app.lsblk").Lsblk
```

## Privilege escalation

Most `lsblk` listing operations are unprivileged, but some environments
restrict access to block-device metadata. If you need elevation, use
`wardlib.tools.with`.

```lua
local with = require("wardlib.tools.with")

local cmd = Lsblk.list(nil, { json = true })
local data = with.with(with.middleware.sudo(), cmd):output()
```

## Options: `LsblkOpts`

- `json: boolean?` — `-J` / `--json`
- `output: string|string[]?` — `-o <cols>` (string or array joined by commas)
- `bytes: boolean?` — `-b`
- `paths: boolean?` — `-p`
- `fs: boolean?` — `-f`
- `all: boolean?` — `-a`
- `nodeps: boolean?` — `-d`
- `list: boolean?` — `-l`
- `raw: boolean?` — `-r`
- `noheadings: boolean?` — `-n`
- `sort: string?` — `--sort <col>`
- `tree: boolean?` — `--tree`
- `extra: string[]?` — appended after modeled options

## API

### `Lsblk.list(devices, opts)`

Construct an `lsblk` command.

Builds: `lsblk <opts...> [devices...]`

```lua
Lsblk.list(devices: string|string[]|nil, opts: LsblkOpts|nil) -> ward.Cmd
```

Notes:

- If `devices` is `nil`, `lsblk` enumerates all block devices.

## Examples

### Parse JSON output

```lua
local out = require("wardlib.tools.out")

local data = out.cmd(Lsblk.list(nil, { json = true }))
  :label("lsblk -J")
  :json()

-- util-linux typically returns: { blockdevices = [...] }
local devs = data.blockdevices or {}
```

### Select specific columns

```lua
-- lsblk -o NAME,SIZE,TYPE,MOUNTPOINT -J
local out = require("wardlib.tools.out")

local data = out.cmd(Lsblk.list(nil, {
  json = true,
  output = { "NAME", "SIZE", "TYPE", "MOUNTPOINT" },
}))
  :label("lsblk -o ... -J")
  :json()
```

### Raw, no headings

```lua
-- lsblk -nrp -o NAME,SIZE
Lsblk.list(nil, { noheadings = true, raw = true, paths = true, output = { "NAME", "SIZE" } }):run()
```
