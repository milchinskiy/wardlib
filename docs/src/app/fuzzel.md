# fuzzel

`fuzzel` is a Wayland-native application launcher. It also supports a `--dmenu`
mode compatible with `dmenu`-style pipelines.

> This module constructs `ward.process.cmd(...)` invocations; it does not parse output.
> consumers can use `wardlib.tools.out` (or their own parsing) on the `:output()`
> result.

## Import

```lua
local Fuzzel = require("wardlib.app.fuzzel").Fuzzel
```

## API

### `Fuzzel.bin`

Executable name or path (default: `"fuzzel"`).

### `Fuzzel.launcher(opts)`

Builds: `fuzzel <opts...>`

### `Fuzzel.dmenu(opts)`

Builds: `fuzzel --dmenu <opts...>`

## Options

### `FuzzelOpts`

- `config: string?` → `--config <file>`
- `output: string?` → `-o <output>`
- `font: string?` → `-f <font>`
- `prompt: string?` → `-p <prompt>`
- `prompt_only: string?` → `--prompt-only <prompt>`
- `hide_prompt: boolean?` → `--hide-prompt`
- `placeholder: string?` → `--placeholder <text>`
- `search: string?` → `--search <text>`
- `no_icons: boolean?` → `-I`
- `anchor: string?` → `-a <anchor>`
- `lines: number?` → `-l <n>`
- `width: number?` → `-w <n>`
- `no_sort: boolean?` → `--no-sort`
- `extra: string[]?` → extra argv appended after modeled options

## Examples

### Simple launcher

```lua
local Fuzzel = require("wardlib.app.fuzzel").Fuzzel

Fuzzel.launcher({ prompt = "Run" }):output()
```

### `--dmenu` mode

```lua
local Fuzzel = require("wardlib.app.fuzzel").Fuzzel

Fuzzel.dmenu({ placeholder = "Type..." }):output()
```
