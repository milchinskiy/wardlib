# xbps

`app.xbps` is a thin wrapper around Void Linux XBPS tooling
(`xbps-install`, `xbps-remove`, `xbps-query`) that constructs
`ward.process.cmd(...)` invocations.

> This module constructs `ward.process.cmd(...)` invocations; it does not parse output.
> consumers can use `wardlib.tools.out` (or their own parsing) on the `:output()`
> result.

## Import

```lua
local Xbps = require("wardlib.app.xbps").Xbps
```

## Running with elevated privileges

Most `xbps-install` / `xbps-remove` operations require root. Instead of passing
`{ sudo = true }` to this module (not supported), use `wardlib.tools.with`.

```lua
local w = require("wardlib.tools.with")
local Xbps = require("wardlib.app.xbps").Xbps

-- sudo -n xbps-install -S
w.with(w.middleware.sudo(), Xbps.sync()):run()
```

## API

All functions return a `ward.Cmd`.

### `Xbps.install(pkgs, opts)`

Builds: `xbps-install <common opts...> <install opts...> <pkgs...>`.

### `Xbps.sync(opts)`

Builds: `xbps-install <common opts...> -S`.

### `Xbps.upgrade(opts)`

Builds: `xbps-install <common opts...> <install opts...> -Su`.

### `Xbps.remove(pkgs, opts)`

Builds: `xbps-remove <common opts...> <remove opts...> <pkgs...>`.

### `Xbps.remove_orphans(opts)`

Builds: `xbps-remove <common opts...> [-y] -o`.

### `Xbps.clean_cache(opts, all)`

Builds: `xbps-remove <common opts...> [-y] -O`.

If `all = true`, uses `-OO`.

### `Xbps.search(pattern, opts)`

Builds: `xbps-query <common opts...> [--regex] -Rs <pattern>`.

### `Xbps.info(pkg, opts)`

Builds: `xbps-query <common opts...> -S <pkg>`.

### `Xbps.list_installed(opts)`

Builds: `xbps-query <common opts...> -l`.

### `Xbps.list_manual(opts)`

Builds: `xbps-query <common opts...> -m`.

## Options

### `XbpsCommonOpts`

Modeled fields:

- `rootdir` (string): `-r <dir>`
- `config` (string): `-C <dir>`
- `cachedir` (string): `-c <dir>`
- `repositories` (string[]): repeatable `--repository <url>`
- `extra` (string[]): extra args appended after modeled options

### `XbpsInstallOpts`

Extends `XbpsCommonOpts`.

Modeled fields:

- `yes` (boolean): `-y`
- `automatic` (boolean): `-A`
- `force` (boolean): `-f`

### `XbpsRemoveOpts`

Extends `XbpsCommonOpts`.

Modeled fields:

- `yes` (boolean): `-y`
- `recursive` (boolean): `-R`
- `force` (boolean): `-f`
- `dry_run` (boolean): `-n`

### `XbpsSearchOpts`

Extends `XbpsCommonOpts`.

Modeled fields:

- `regex` (boolean): `--regex`

## Examples

```lua
local w = require("wardlib.tools.with")
local Xbps = require("wardlib.app.xbps").Xbps

-- sudo -n xbps-install -y -Su
w.with(w.middleware.sudo(), Xbps.upgrade({ yes = true })):run()

-- sudo -n xbps-install -y curl git
w.with(w.middleware.sudo(), Xbps.install({ "curl", "git" }, { yes = true })):run()

-- xbps-query --regex -Rs '^lua'
local r = Xbps.search("^lua", { regex = true }):output()
```
