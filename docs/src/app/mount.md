# app.mount

`app.mount` provides thin command-construction wrappers around util-linux
`mount` and `umount`.

> This module constructs `ward.process.cmd(...)` invocations; it does not parse output.
> consumers can use `wardlib.tools.out` (or their own parsing) on the `:output()`
> result.

This module models a small set of commonly used options. Everything unmodeled
can be passed through via `opts.extra`.

## Import

```lua
local Mount = require("wardlib.app.mount").Mount
```

## Privilege escalation

Mounting and unmounting typically require elevated privileges. Prefer
`wardlib.tools.with` so escalation is explicit and scoped.

```lua
local with = require("wardlib.tools.with")

with.with(with.middleware.sudo(), function()
  Mount.mount("/dev/sdb1", "/mnt/data", { fstype = "ext4" }):run()
end)
```

## Options

### `MountOpts`

- `fstype: string?` — adds `-t <fstype>`
- `options: string|string[]?` — adds `-o <opts>` (string or list joined by commas)
- `readonly: boolean?` — adds `ro` to `-o`
- `bind: boolean?` — adds `--bind`
- `rbind: boolean?` — adds `--rbind`
- `move: boolean?` — adds `--move`
- `verbose: boolean?` — adds `-v`
- `fake: boolean?` — adds `-f`
- `extra: string[]?` — appended before positional args

### `UmountOpts`

- `lazy: boolean?` — adds `-l`
- `force: boolean?` — adds `-f`
- `recursive: boolean?` — adds `-R`
- `verbose: boolean?` — adds `-v`
- `extra: string[]?` — appended before positional args

## API

### `Mount.mount(source, target, opts)`

Builds: `mount [opts] [source] [target]`

```lua
Mount.mount(source: string|nil, target: string|nil, opts: MountOpts|nil) -> ward.Cmd
```

Notes:

- If both `source` and `target` are `nil`, this corresponds to plain `mount`
  (printing the current mount table).

### `Mount.umount(target, opts)`

Builds: `umount [opts] <target>`

```lua
Mount.umount(target: string, opts: UmountOpts|nil) -> ward.Cmd
```

## Examples

### Show current mounts

```lua
local out = require("wardlib.tools.out")

local mounts = out.cmd(Mount.mount(nil, nil))
  :label("mount")
  :lines()
```

### Mount a device read-only

```lua
-- mount -t ext4 -o ro /dev/sdb1 /mnt/data
Mount.mount("/dev/sdb1", "/mnt/data", { fstype = "ext4", readonly = true }):run()
```

### Bind mount

```lua
-- mount --bind /src /dst
Mount.mount("/src", "/dst", { bind = true }):run()
```

### Unmount recursively

```lua
-- umount -R /mnt/data
Mount.umount("/mnt/data", { recursive = true }):run()
```
