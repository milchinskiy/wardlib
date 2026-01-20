# app.mkfs

`app.mkfs` is a thin command-construction wrapper around `mkfs` and
`mkfs.<fstype>` frontends.

> This module constructs `ward.process.cmd(...)` invocations; it does not parse output.
> consumers can use `wardlib.tools.out` (or their own parsing) on the `:output()`
> result.

The wrapper prefers `mkfs.<fstype>` when present in PATH; otherwise it falls
back to `mkfs -t <fstype>`.

> Filesystem-specific flags are intentionally not modeled. Use `opts.extra`.

## Import

```lua
local Mkfs = require("wardlib.app.mkfs").Mkfs
```

## Privilege escalation and safety

Formatting filesystems is destructive and almost always requires elevated
privileges.

Use `wardlib.tools.with` middleware so privilege escalation is explicit and
scoped:

```lua
local with = require("wardlib.tools.with")

with.with(with.middleware.sudo(), function()
  -- mkfs.ext4 /dev/sdb1
  Mkfs.ext4("/dev/sdb1"):run()
end)
```

## Options: `MkfsOpts`

- `bin: string?`
  - Override the binary (name or absolute path).
  - When set, it is used directly and **no** `-t <fstype>` is added.
- `extra: string[]?`
  - Extra args appended before the device.
  - Use this for filesystem-specific flags (for example, labels, force flags, etc.).

## API

### `Mkfs.format(fstype, device, opts)`

Format a device with an explicit filesystem type.

If `mkfs.<fstype>` exists in PATH, it is used directly. Otherwise:

- Builds: `mkfs -t <fstype> <extra...> <device>`

```lua
Mkfs.format(fstype: string, device: string, opts: MkfsOpts|nil) -> ward.Cmd
```

### Convenience helpers

These call `Mkfs.format(...)` with the corresponding fstype:

- `Mkfs.ext4(device, opts)`
- `Mkfs.xfs(device, opts)`
- `Mkfs.btrfs(device, opts)`
- `Mkfs.vfat(device, opts)`
- `Mkfs.f2fs(device, opts)`

## Examples

### Create an ext4 filesystem with extra flags

```lua
local with = require("wardlib.tools.with")

-- mkfs.ext4 -F -L data /dev/sdb1
with.with(with.middleware.sudo(), function()
  Mkfs.ext4("/dev/sdb1", { extra = { "-F", "-L", "data" } }):run()
end)
```

### Use the generic formatter

```lua
-- mkfs -t xfs -f /dev/sdb2
Mkfs.format("xfs", "/dev/sdb2", { extra = { "-f" } })
```

### Force a specific binary

This bypasses the `mkfs.<fstype>` / `mkfs -t` selection logic.

```lua
-- /usr/sbin/mkfs.ext4 -F /dev/sdb1
Mkfs.format("ext4", "/dev/sdb1", { bin = "/usr/sbin/mkfs.ext4", extra = { "-F" } })
```
