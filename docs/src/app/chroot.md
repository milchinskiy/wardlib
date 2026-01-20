# chroot

Thin wrapper around `chroot` (GNU coreutils).

> This module constructs `ward.process.cmd(...)` invocations; it does not parse output.
> consumers can use `wardlib.tools.out` (or their own parsing) on the `:output()`
> result.

The wrapper models the common GNU flags:

- `--userspec=USER:GROUP`
- `--groups=G1,G2,...`
- `--skip-chdir`

Everything else can be passed via `opts.extra`.

## Import

```lua
local Chroot = require("wardlib.app.chroot").Chroot
```

## Privilege escalation

Entering a chroot typically requires elevated privileges. This module does not
implement `sudo`/`doas` options; use `wardlib.tools.with`.

```lua
local w = require("wardlib.tools.with")
local Chroot = require("wardlib.app.chroot").Chroot

w.with(w.middleware.sudo(), Chroot.run("/mnt/root", { "/usr/bin/id" })):run()
```

## API

### `Chroot.bin`

Executable name or path used for `chroot`.

### `Chroot.run(root, argv, opts)`

Builds: `chroot [opts...] <root> [command [args...]]`

- `root: string` — new root directory.
- `argv: string[]|nil` — command and arguments inside the chroot. When `nil`,
`chroot` runs the default shell.
- `opts: ChrootOpts|nil` — modeled options.

## Options (`ChrootOpts`)

- `userspec: string|nil` — `--userspec=<user>:<group>`.
- `groups: string|string[]|nil` — `--groups=<g1>,<g2>`.
- `skip_chdir: boolean|nil` — `--skip-chdir`.
- `extra: string[]|nil` — pass-through args appended before positional args.

## Examples

### Run a command inside a root

```lua
local Chroot = require("wardlib.app.chroot").Chroot

-- chroot /mnt/root /bin/sh -lc 'echo ok'
local cmd = Chroot.run("/mnt/root", { "/bin/sh", "-lc", "echo ok" })
```

### Run as a specific user/group

```lua
local Chroot = require("wardlib.app.chroot").Chroot

-- chroot --userspec=1000:1000 --groups=wheel,audio --skip-chdir /mnt/root /usr/bin/id
local cmd = Chroot.run("/mnt/root", { "/usr/bin/id" }, {
  userspec = "1000:1000",
  groups = { "wheel", "audio" },
  skip_chdir = true,
})
```
