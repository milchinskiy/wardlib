# apt-get

`app.aptget` is a thin wrapper around Debian/Ubuntu's `apt-get` that constructs
`ward.process.cmd(...)` invocations.

This module does not parse output.

## Import

```lua
local AptGet = require("wardlib.app.aptget").AptGet
```

## Running with elevated privileges

Most `apt-get` operations require root. Instead of passing `{ sudo = true }` to
this module (not supported), use `wardlib.tools.with` to install a process
middleware.

```lua
local w = require("wardlib.tools.with")
local AptGet = require("wardlib.app.aptget").AptGet

-- sudo -n apt-get update
w.with(w.middleware.sudo(), AptGet.update()):run()
```

## API

All functions return a `ward.Cmd`.

### `AptGet.cmd(subcmd, argv, opts)`

Generic helper that builds: `apt-get <common opts...> <subcmd> [argv...]`.

### `AptGet.update(opts)`

Builds: `apt-get update`.

### `AptGet.upgrade(opts)`

Builds: `apt-get upgrade`.

### `AptGet.dist_upgrade(opts)`

Builds: `apt-get dist-upgrade`.

### `AptGet.install(pkgs, opts)`

Builds: `apt-get install <pkgs...>` (plus modeled options).

### `AptGet.remove(pkgs, opts)`

Builds: `apt-get remove <pkgs...>`.

If `opts.purge = true`, builds: `apt-get purge <pkgs...>`.

### `AptGet.autoremove(opts)`

Builds: `apt-get autoremove`.

### `AptGet.clean(opts)`

Builds: `apt-get clean`.

## Options

### `AptGetCommonOpts`

Modeled fields:

- `assume_yes` (boolean): `-y`
- `quiet` (boolean|integer): `-q` / `-qq` (true or 1 => `-q`, 2 => `-qq`)
- `extra` (string[]): extra args appended after modeled options

### `AptGetInstallOpts`

Extends `AptGetCommonOpts`.

Modeled fields:

- `no_install_recommends` (boolean): `--no-install-recommends`

### `AptGetRemoveOpts`

Extends `AptGetCommonOpts`.

Modeled fields:

- `purge` (boolean): uses `purge` instead of `remove`

## Examples

```lua
local w = require("wardlib.tools.with")
local AptGet = require("wardlib.app.aptget").AptGet

-- sudo -n apt-get -qq -y upgrade
w.with(w.middleware.sudo(), AptGet.upgrade({ assume_yes = true, quiet = 2 })):run()

-- sudo -n apt-get -y install --no-install-recommends curl git
w.with(w.middleware.sudo(), AptGet.install({ "curl", "git" }, {
  assume_yes = true,
  no_install_recommends = true,
})):run()
```