# app.gzip

`app.gzip` is a thin command-construction wrapper around the `gzip` binary.
It returns `ward.process.cmd(...)` objects.

> This module constructs `ward.process.cmd(...)` invocations; it does not parse output.
> consumers can use `wardlib.tools.out` (or their own parsing) on the `:output()`
> result.

## Import

```lua
local Gzip = require("wardlib.app.gzip").Gzip
```

## Privilege escalation

`gzip` is typically unprivileged, but you may need elevated privileges when
working in root-owned directories. Use `wardlib.tools.with` middleware for
predictable privilege handling.

```lua
local with = require("wardlib.tools.with")

with.with(with.middleware.sudo(), function()
  -- Example: compress a file in a root-owned directory
  Gzip.compress("/var/log/app.log", { keep = true }):run()
end)
```

## Options: `GzipOpts`

- `decompress: boolean?` — `-d`
- `keep: boolean?` — `-k`
- `force: boolean?` — `-f`
- `stdout: boolean?` — `-c`
- `recursive: boolean?` — `-r`
- `test: boolean?` — `-t`
- `list: boolean?` — `-l`
- `verbose: boolean?` — `-v`
- `quiet: boolean?` — `-q`
- `suffix: string?` — `-S <suffix>`
- `level: integer?` — compression level `-1`..`-9`
- `extra: string[]?` — appended after modeled options

Notes:

- `paths` must be non-empty.
- When `level` is set, it is validated as an integer in `[1..9]`.

## API

### `Gzip.run(paths, opts)`

Builds: `gzip <opts...> -- <paths...>`

```lua
Gzip.run(paths: string|string[], opts: GzipOpts|nil) -> ward.Cmd
```

### `Gzip.compress(paths, opts)`

Convenience for compression.

- Forces `decompress = false`.
- Builds the same shape as `Gzip.run`.

```lua
Gzip.compress(paths: string|string[], opts: GzipOpts|nil) -> ward.Cmd
```

### `Gzip.decompress(paths, opts)`

Convenience for decompression.

- Forces `decompress = true`.

```lua
Gzip.decompress(paths: string|string[], opts: GzipOpts|nil) -> ward.Cmd
```

### `Gzip.raw(argv, opts)`

Low-level escape hatch.

Builds: `gzip <modeled-opts...> <argv...>`

```lua
Gzip.raw(argv: string|string[], opts: GzipOpts|nil) -> ward.Cmd
```

## Examples

### Compress a file and keep the original

```lua
-- gzip -k -9 -- data.json
local cmd = Gzip.compress("data.json", { keep = true, level = 9 })
cmd:run()
```

### Decompress a file (force overwrite)

```lua
-- gzip -d -f -- data.json.gz
Gzip.decompress("data.json.gz", { force = true }):run()
```

### Stream compressed data to stdout

```lua
-- gzip -c -- data.json
local res = Gzip.run("data.json", { stdout = true }):output()
-- res.stdout contains compressed bytes
```

### List gzip members and parse output

`gzip -l` emits a small table. Use `wardlib.tools.out` to consume it.

```lua
local out = require("wardlib.tools.out")

local lines = out.cmd(Gzip.run("data.json.gz", { list = true }))
  :label("gzip -l data.json.gz")
  :lines()

-- `lines` is an array of text rows; you can parse it further if needed.
```
