# yay

`app.yay` is a thin wrapper around `yay` (an Arch AUR helper) that constructs
`ward.process.cmd(...)` invocations.

This module does not parse output.

## Import

```lua
local Yay = require("wardlib.app.yay").Yay
```

## Notes on privileges

`yay` typically invokes `sudo` internally when needed (depending on your
configuration). This wrapper does not provide a `{ sudo = true }` option.

If you intentionally want to run `yay` itself under `sudo` / `doas`, wrap the
returned command using `wardlib.tools.with`:

```lua
local w = require("wardlib.tools.with")
local Yay = require("wardlib.app.yay").Yay

w.with(w.middleware.sudo(), Yay.upgrade()):run()
```

## API

All functions return a `ward.Cmd`.

### `Yay.sync(opts)`

Builds: `yay -Sy` (or `-Syy` if `opts.refresh = true`).

### `Yay.upgrade(opts)`

Builds: `yay -Syu` (or `-Syyu` if `opts.refresh = true`).

### `Yay.install(pkgs, opts)`

Builds: `yay -S <pkgs...>` (plus modeled options).

### `Yay.remove(pkgs, opts)`

Builds: `yay -R[flags] <pkgs...>`.

Flags are derived from:

- `opts.nosave` => `n`
- `opts.recursive` => `s`
- `opts.cascade` => `c`

### `Yay.search(pattern, opts)`

Builds: `yay -Ss <pattern>`.

### `Yay.info(pkg, opts)`

Builds: `yay -Qi <pkg>`.

## Options

### `YayCommonOpts`

Modeled fields:

- `needed` (boolean): `--needed`
- `noconfirm` (boolean): `--noconfirm`
- `extra` (string[]): extra args appended after modeled options

### `YaySyncOpts`

Extends `YayCommonOpts`.

Modeled fields:

- `refresh` (boolean): uses `-Syy` / `-Syyu` instead of `-Sy` / `-Syu`

### `YayRemoveOpts`

Extends `YayCommonOpts`.

Modeled fields:

- `recursive` (boolean): include `s` flag (`-Rs`)
- `nosave` (boolean): include `n` flag (`-Rn`)
- `cascade` (boolean): include `c` flag (`-Rc`)

## Examples

```lua
local Yay = require("wardlib.app.yay").Yay

-- yay -Syu
Yay.upgrade():run()

-- yay -S --needed --noconfirm google-chrome
Yay.install("google-chrome", { needed = true, noconfirm = true }):run()

-- yay -Ss neovim
local r = Yay.search("neovim"):output()
```
