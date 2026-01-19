# dnf

`dnf` is the package manager for Fedora and many RHEL-family distributions.

> This wrapper constructs a `ward.process.cmd(...)` invocation; it does not
> parse output.

## Import

```lua
local Dnf = require("wardlib.app.dnf").Dnf
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

- `sudo`: prefix with `sudo`
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

-- sudo dnf -y upgrade
local cmd2 = Dnf.upgrade(nil, { sudo = true, assume_yes = true })

-- dnf --enablerepo=updates search kernel
local cmd3 = Dnf.search("kernel", { enable_repo = "updates" })
```
