# tofi

`tofi` is a Wayland-native menu / launcher. Some distributions ship helper
binaries such as `tofi-run` and `tofi-drun`.

> This module constructs `ward.process.cmd(...)` invocations; it does not parse output.
> consumers can use `wardlib.tools.out` (or their own parsing) on the `:output()`
> result.

## Import

```lua
local Tofi = require("wardlib.app.tofi").Tofi
```

## API

### `Tofi.bin`

Executable name or path (default: `"tofi"`).

### `Tofi.bin_run`

Executable name or path (default: `"tofi-run"`).

### `Tofi.bin_drun`

Executable name or path (default: `"tofi-drun"`).

### `Tofi.menu(opts)`

Builds: `tofi <opts...>`

### `Tofi.run(opts)`

Builds: `tofi-run <opts...>`

### `Tofi.drun(opts)`

Builds: `tofi-drun <opts...>`

## Options

### `TofiOpts`

- `config: string?` → `-c <file>`
- `prompt_text: string?` → `--prompt-text <text>`
- `num_results: number?` → `--num-results <n>`
- `require_match: boolean?` → `--require-match`
- `fuzzy_match: boolean?` → `--fuzzy-match`
- `width: string?` → `--width <w>`
- `height: string?` → `--height <h>`
- `font: string?` → `--font <font>`
- `defines: table<string, any>?` → additional `--key <value>` pairs
  - stable key order
  - `true` emits `--key`
  - `false`/`nil` are skipped
- `extra: string[]?` → extra argv appended after modeled options

## Examples

### `tofi-run` with a prompt

```lua
local Tofi = require("wardlib.app.tofi").Tofi

Tofi.run({
  config = "tofi.conf",
  prompt_text = "Run",
  require_match = true,
}):output()
```
