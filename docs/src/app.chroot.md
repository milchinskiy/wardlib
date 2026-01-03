# chroot

Thin wrapper around `chroot`.

This module models the common GNU coreutils flags:

- `--userspec=USER:GROUP`
- `--groups=G1,G2,...`
- `--skip-chdir`

Everything else can be passed via `opts.extra`.

## Run a command inside a root

```lua
local Chroot = require("app.chroot").Chroot

-- Equivalent to: chroot /mnt/root /bin/sh -lc 'echo ok'
local cmd = Chroot.run("/mnt/root", { "/bin/sh", "-lc", "echo ok" })

-- cmd:run()
```

## Run as specific user/group

```lua
local Chroot = require("app.chroot").Chroot

-- Equivalent to:
--   chroot --userspec=1000:1000 --groups=wheel,audio --skip-chdir /mnt/root /usr/bin/id
local cmd = Chroot.run("/mnt/root", { "/usr/bin/id" }, {
  userspec = "1000:1000",
  groups = { "wheel", "audio" },
  skip_chdir = true,
})
```
