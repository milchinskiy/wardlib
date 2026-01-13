# zypper

`zypper` is the package manager for openSUSE and SUSE Linux Enterprise.

> This wrapper constructs a `ward.process.cmd(...)` invocation; it does not
> parse output.

## Import

```lua
local Zypper = require("wardlib.app.zypper").Zypper
```

## API

### `Zypper.refresh(opts)`

Builds: `zypper <opts...> refresh`

### `Zypper.install(pkgs, opts)`

Builds: `zypper <opts...> install <pkgs...>`

### `Zypper.remove(pkgs, opts)`

Builds: `zypper <opts...> remove <pkgs...>`

### `Zypper.update(pkgs, opts)`

Builds: `zypper <opts...> update [pkgs...]`

If `pkgs` is nil, updates all packages.

### `Zypper.dup(opts)`

Builds: `zypper <opts...> dup`

### `Zypper.search(term, opts)`

Builds: `zypper <opts...> search <term>`

### `Zypper.info(pkgs, opts)`

Builds: `zypper <opts...> info <pkgs...>`

### `Zypper.repos_list(opts)`

Builds: `zypper <opts...> repos`

### `Zypper.addrepo(uri, alias, opts)`

Builds: `zypper <opts...> addrepo <uri> <alias>`

### `Zypper.removerepo(alias, opts)`

Builds: `zypper <opts...> removerepo <alias>`

### `Zypper.cmd(subcmd, argv, opts)`

Generic helper for `zypper <opts...> <subcmd> [argv...]`.

### `Zypper.raw(argv, opts)`

Builds: `zypper <opts...> <argv...>`

## Options (`ZypperCommonOpts`)

Modeled fields:

- `sudo`: prefix with `sudo`
- Interactivity: `non_interactive (--non-interactive)`
- Logging: `quiet (-q)`, `verbose (-v)`
- Metadata: `refresh (--refresh)`, `no_refresh (--no-refresh)` (mutually exclusive)
- License handling: `auto_agree_with_licenses (--auto-agree-with-licenses)`
- GPG handling: `gpg_auto_import_keys (--gpg-auto-import-keys)`, `no_gpg_checks (--no-gpg-checks)`
- Repo restriction: `repos (-r <alias>)` (repeatable)
- Escape hatch: `extra`

## Examples

```lua
local Zypper = require("wardlib.app.zypper").Zypper

-- zypper --non-interactive refresh
local cmd1 = Zypper.refresh({ non_interactive = true })

-- sudo zypper --non-interactive --auto-agree-with-licenses install curl jq
local cmd2 = Zypper.install({ "curl", "jq" }, {
  sudo = true,
  non_interactive = true,
  auto_agree_with_licenses = true,
})

-- zypper -r oss -r update search kernel
local cmd3 = Zypper.search("kernel", { repos = { "oss", "update" } })
```
