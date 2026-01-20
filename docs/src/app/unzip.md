# unzip

`unzip` extracts and inspects zip archives (Info-ZIP).

> This module constructs `ward.process.cmd(...)` invocations; it does not parse output.
> consumers can use `wardlib.tools.out` (or their own parsing) on the `:output()`
> result.

Safety note:

- Info-ZIP `unzip` does **not** support `--` as end-of-options. For safety,
this wrapper rejects zip paths (and optional file lists) that start with `-`.
- `opts.password` uses `unzip -P <password>`, which may be visible to other
users on multi-user systems.

## Import

```lua
local Unzip = require("wardlib.app.unzip").Unzip
```

## API

### `Unzip.extract(zip_path, opts)`

Builds: `unzip <opts...> <zip_path> [files...] [-x <exclude...>] [-d <to>]`

### `Unzip.list(zip_path, opts)`

Builds: `unzip -l <opts...> <zip_path> ...`

### `Unzip.test(zip_path, opts)`

Builds: `unzip -t <opts...> <zip_path> ...`

### `Unzip.raw(argv, opts)`

Builds: `unzip <opts...> <argv...>`

## Options (`UnzipOpts`)

- `to: string?` — destination directory (`-d <dir>`)
- `files: string|string[]?` — optional file list to extract
- `exclude: string|string[]?` — patterns appended after `-x`
- `overwrite: boolean?` — `-o`
- `never_overwrite: boolean?` — `-n` (mutually exclusive with `overwrite`)
- `quiet: boolean?` — `-q`
- `junk_paths: boolean?` — `-j`
- `list: boolean?` — `-l` (low-level; prefer `Unzip.list()` )
- `test: boolean?` — `-t` (low-level; prefer `Unzip.test()` )
- `password: string?` — `-P <password>`
- `extra: string[]?` — extra argv appended after modeled options

## Examples

### Extract into a destination directory

```lua
local Unzip = require("wardlib.app.unzip").Unzip

-- unzip -o a.zip -d out
local cmd = Unzip.extract("a.zip", { overwrite = true, to = "out" })
```

### Extract only specific files and exclude patterns

```lua
local Unzip = require("wardlib.app.unzip").Unzip

-- unzip a.zip x y -x "*.tmp" "*.bak" -d out
local cmd = Unzip.extract("a.zip", {
  files = { "x", "y" },
  exclude = { "*.tmp", "*.bak" },
  to = "out",
})
```

### List contents

```lua
local Unzip = require("wardlib.app.unzip").Unzip

-- unzip -q -l a.zip
local cmd = Unzip.list("a.zip", { quiet = true })
```

### Test zip integrity

```lua
local Unzip = require("wardlib.app.unzip").Unzip

-- unzip -t a.zip
local cmd = Unzip.test("a.zip")
```
