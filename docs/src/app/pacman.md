# pacman

`app.pacman` is a thin wrapper around Arch's `pacman` that constructs
`ward.process.cmd(...)` invocations.

This module does not parse output.

## Import

```lua
local Pacman = require("wardlib.app.pacman").Pacman
```

## Running with elevated privileges

Most pacman operations require root. Instead of passing `{ sudo = true }` to
this module (not supported), use `wardlib.tools.with`.

```lua
local w = require("wardlib.tools.with")
local Pacman = require("wardlib.app.pacman").Pacman

-- sudo -n pacman -Sy
w.with(w.middleware.sudo(), Pacman.sync()):run()
```

## API

All functions return a `ward.Cmd`.

### `Pacman.sync(opts)`

Builds: `pacman -Sy` (or `-Syy` if `opts.refresh = true`).

### `Pacman.upgrade(opts)`

Builds: `pacman -Syu` (or `-Syyu` if `opts.refresh = true`).

### `Pacman.install(pkgs, opts)`

Builds: `pacman -S <pkgs...>` (plus modeled options).

### `Pacman.remove(pkgs, opts)`

Builds: `pacman -R[flags] <pkgs...>`.

Flags are derived from:

- `opts.nosave` => `n`
- `opts.recursive` => `s`
- `opts.cascade` => `c`

### `Pacman.search(pattern, opts)`

Builds: `pacman -Ss <pattern>`.

### `Pacman.info(pkg, opts)`

Builds: `pacman -Qi <pkg>`.

### `Pacman.list_installed(opts)`

Builds: `pacman -Q`.

## Options

### `PacmanCommonOpts`

Modeled fields:

- `noconfirm` (boolean): `--noconfirm`
- `extra` (string[]): extra args appended after modeled options

### `PacmanSyncOpts`

Extends `PacmanCommonOpts`.

Modeled fields:

- `refresh` (boolean): uses `-Syy` / `-Syyu` instead of `-Sy` / `-Syu`

### `PacmanInstallOpts`

Extends `PacmanCommonOpts`.

Modeled fields:

- `needed` (boolean): `--needed`

### `PacmanRemoveOpts`

Extends `PacmanCommonOpts`.

Modeled fields:

- `recursive` (boolean): include `s` flag (`-Rs`)
- `nosave` (boolean): include `n` flag (`-Rn`)
- `cascade` (boolean): include `c` flag (`-Rc`)

## Examples

```lua
local w = require("wardlib.tools.with")
local Pacman = require("wardlib.app.pacman").Pacman

-- sudo -n pacman -Syu --noconfirm
w.with(w.middleware.sudo(), Pacman.upgrade({ noconfirm = true })):run()

-- sudo -n pacman -S --needed --noconfirm curl git
w.with(w.middleware.sudo(), Pacman.install({ "curl", "git" }, {
  needed = true,
  noconfirm = true,
})):run()

-- pacman -Ss lua
local r = Pacman.search("lua"):output()
```
