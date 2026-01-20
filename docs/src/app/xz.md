# xz

`xz` compresses and decompresses files using LZMA2.

> This module constructs `ward.process.cmd(...)` invocations; it does not parse output.
> consumers can use `wardlib.tools.out` (or their own parsing) on the `:output()`
> result.

Notes:

- `Xz.run()` always inserts `--` before paths.
- `opts.level` is modeled as `0..9` and is emitted as `-<level>`.

## Import

```lua
local Xz = require("wardlib.app.xz").Xz
```

## API

### `Xz.run(paths, opts)`

Builds: `xz <opts...> -- <paths...>`

### `Xz.compress(paths, opts)`

Convenience: compression (ensures `decompress = false`).

### `Xz.decompress(paths, opts)`

Convenience: decompression (`-d`).

### `Xz.raw(argv, opts)`

Builds: `xz <opts...> <argv...>`

## Options (`XzOpts`)

- `decompress: boolean?` — `-d`
- `keep: boolean?` — `-k`
- `force: boolean?` — `-f`
- `stdout: boolean?` — `-c`
- `verbose: boolean?` — `-v`
- `quiet: boolean?` — `-q`
- `extreme: boolean?` — `-e`
- `level: integer?` — compression level `-0..-9`
- `threads: integer?` — `-T <n>` (0 = auto)
- `extra: string[]?` — extra argv appended after modeled options

## Examples

### Compress with level and threads

```lua
local Xz = require("wardlib.app.xz").Xz

-- xz -e -6 -T 0 -- data.json
local cmd = Xz.compress("data.json", { level = 6, extreme = true, threads = 0 })
```

### Decompress

```lua
local Xz = require("wardlib.app.xz").Xz

-- xz -d -k -- data.json.xz
local cmd = Xz.decompress("data.json.xz", { keep = true })
```

### Write decompressed data to stdout

```lua
local Xz = require("wardlib.app.xz").Xz

-- xz -d -c -- file.xz
local cmd = Xz.decompress("file.xz", { stdout = true })
```

### Pass-through extra xz flags

```lua
local Xz = require("wardlib.app.xz").Xz

-- xz --check=crc64 -- file
local cmd = Xz.run("file", { extra = { "--check=crc64" } })
```
