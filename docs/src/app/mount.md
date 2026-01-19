# mount

Thin wrappers around `mount` and `umount` that build command invocations.

Use `opts.extra` to pass flags not modeled yet.

## Mount a block device

```lua
local Mount = require("wardlib.app.mount").Mount

-- Equivalent to: mount -t ext4 -o noatime /dev/sda1 /mnt/data
local cmd = Mount.mount("/dev/sda1", "/mnt/data", {
  fstype = "ext4",
  options = { "noatime" },
})
```

## Mount read-only

```lua
local Mount = require("wardlib.app.mount").Mount

-- Equivalent to: mount -o ro /dev/sda1 /mnt/data
local cmd = Mount.mount("/dev/sda1", "/mnt/data", {
  readonly = true,
})
```

## Bind mount

```lua
local Mount = require("wardlib.app.mount").Mount

-- Equivalent to: mount --bind /src /dst
local cmd = Mount.mount("/src", "/dst", {
  bind = true,
})
```

## Umount

```lua
local Mount = require("wardlib.app.mount").Mount

-- Equivalent to: umount -l /mnt/data
local cmd = Mount.umount("/mnt/data", {
  lazy = true,
})
```
