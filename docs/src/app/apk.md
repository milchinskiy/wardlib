# apk

`app.apk` is a thin wrapper around Alpine's `apk` that constructs
`ward.process.cmd(...)` invocations.

> This module constructs `ward.process.cmd(...)` invocations; it does not parse output.
> consumers can use `wardlib.tools.out` (or their own parsing) on the `:output()`
> result.

## Import

```lua
local Apk = require("wardlib.app.apk").Apk
```

## Running with elevated privileges

Package management typically requires root. Instead of passing `{ sudo = true }` to
this module (not supported), use `wardlib.tools.with` to install a process
middleware.

```lua
local w = require("wardlib.tools.with")
local Apk = require("wardlib.app.apk").Apk

-- sudo -n apk upgrade
w.with(w.middleware.sudo(), Apk.upgrade()):run()
```

## API

All functions return a `ward.Cmd`.

### `Apk.cmd(subcmd, argv, opts)`

Generic helper that builds: `apk <subcmd> [argv...]`.

### `Apk.update(opts)`

Builds: `apk update`.

### `Apk.upgrade(opts)`

Builds: `apk upgrade`.

### `Apk.add(pkgs, opts)`

Builds: `apk add <opts...> <pkgs...>`.

### `Apk.del(pkgs, opts)`

Builds: `apk del <opts...> <pkgs...>`.

### `Apk.search(pattern, opts)`

Builds: `apk search <pattern>`.

### `Apk.info(pkg, opts)`

Builds: `apk info [pkg]`.

If `pkg` is nil, shows all installed packages.

## Options

### `ApkCommonOpts`

Modeled fields:

- `extra` (string[]): extra args appended after modeled options

### `ApkAddOpts`

Extends `ApkCommonOpts`.

Modeled fields:

- `no_cache` (boolean): `--no-cache`
- `update_cache` (boolean): `--update-cache`
- `virtual` (string): `--virtual <name>`

### `ApkDelOpts`

Extends `ApkCommonOpts`.

Modeled fields:

- `rdepends` (boolean): `--rdepends`

## Examples

```lua
local Apk = require("wardlib.app.apk").Apk

-- apk update
Apk.update():run()

-- apk add --no-cache curl git
Apk.add({ "curl", "git" }, { no_cache = true }):run()

-- apk search curl
local r = Apk.search("curl"):output()
```
