# dnf

`dnf` is the package manager for Fedora and many RHEL-family distributions.

> This module constructs `ward.process.cmd(...)` invocations; it does not parse output.
> consumers can use `wardlib.tools.out` (or their own parsing) on the `:output()`
> result.

## Import

```lua
local Dnf = require("wardlib.app.dnf").Dnf
```

## Running with elevated privileges

Most `dnf` operations require root. Instead of passing `{ sudo = true }` to this
module (not supported), use `wardlib.tools.with`.

```lua
local w = require("wardlib.tools.with")
local Dnf = require("wardlib.app.dnf").Dnf

-- sudo -n dnf -y upgrade
w.with(w.middleware.sudo(), Dnf.upgrade(nil, { assume_yes = true })):run()
```

## API

### `Dnf.install(pkgs, opts)`

Builds: `dnf <opts...> install <pkgs...>`

### `Dnf.remove(pkgs, opts)`

Builds: `dnf <opts...> remove <pkgs...>`

### `Dnf.update(pkgs, opts)`

Builds: `dnf <opts...> update [pkgs...]`

If `pkgs` is nil, updates all packages.

### `Dnf.upgrade(pkgs, opts)`

Builds: `dnf <opts...> upgrade [pkgs...]`

### `Dnf.autoremove(opts)`

Builds: `dnf <opts...> autoremove`

### `Dnf.makecache(opts)`

Builds: `dnf <opts...> makecache`

### `Dnf.search(term, opts)`

Builds: `dnf <opts...> search <term>`

### `Dnf.info(pkgs, opts)`

Builds: `dnf <opts...> info <pkgs...>`

### `Dnf.cmd(subcmd, argv, opts)`

Generic helper for `dnf <opts...> <subcmd> [argv...]`.

### `Dnf.raw(argv, opts)`

Builds: `dnf <opts...> <argv...>`

## Options (`DnfCommonOpts`)

Modeled fields:

- Non-interactive: `assume_yes (-y)`, `assume_no (-n)` (mutually exclusive)
- Logging: `quiet (-q)`, `verbose (-v)`
- Metadata/control: `refresh (--refresh)`, `cacheonly (-C)`
- Solver: `best (--best)`, `allowerasing (--allowerasing)`, `skip_broken (--skip-broken)`
- Verification: `nogpgcheck (--nogpgcheck)`
- Targeting: `releasever (--releasever=...)`, `installroot (--installroot=...)`
- Repos: `enable_repo (--enablerepo=...)`, `disable_repo (--disablerepo=...)`
- Escape hatch: `extra`

## Examples

```lua
local Dnf = require("wardlib.app.dnf").Dnf

-- dnf -y --refresh install git ripgrep
local cmd1 = Dnf.install({ "git", "ripgrep" }, { assume_yes = true, refresh = true })

-- sudo -n dnf -y upgrade
local w = require("wardlib.tools.with")
w.with(w.middleware.sudo(), Dnf.upgrade(nil, { assume_yes = true })):run()

-- dnf --enablerepo=updates search kernel
local cmd3 = Dnf.search("kernel", { enable_repo = "updates" })
```
