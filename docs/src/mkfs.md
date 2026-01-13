# mkfs

Thin wrapper around filesystem formatting tools.

Behavior:

- If `mkfs.<fstype>` is available in `PATH` (for example `mkfs.ext4`), it is used.
- Otherwise, it falls back to `mkfs -t <fstype>`.

Filesystem-specific flags are not modeled; pass them via `opts.extra`.

## Format ext4

```lua
local Mkfs = require("wardlib.app.mkfs").Mkfs

-- If mkfs.ext4 exists:
--   mkfs.ext4 /dev/sda1
-- Otherwise:
--   mkfs -t ext4 /dev/sda1
local cmd = Mkfs.ext4("/dev/sda1")

-- cmd:run()
```

## Format with explicit fstype

```lua
local Mkfs = require("wardlib.app.mkfs").Mkfs

-- Fallback case: mkfs -t xfs /dev/sdb1
local cmd = Mkfs.format("xfs", "/dev/sdb1")
```

## Pass-through extra arguments

```lua
local Mkfs = require("wardlib.app.mkfs").Mkfs

-- Fallback case: mkfs -t xfs -f /dev/sdb1
local cmd = Mkfs.format("xfs", "/dev/sdb1", {
  extra = { "-f" },
})
```

## Use an explicit mkfs binary

```lua
local Mkfs = require("wardlib.app.mkfs").Mkfs

-- Uses this binary directly (no -t inserted):
--   /usr/sbin/mkfs.ext4 /dev/sda1
local cmd = Mkfs.ext4("/dev/sda1", {
  bin = "/usr/sbin/mkfs.ext4",
})
```
