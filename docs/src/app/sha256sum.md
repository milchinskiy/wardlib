# sha256sum

`sha256sum` computes and checks SHA-256 message digests.

> This module constructs `ward.process.cmd(...)` invocations; it does not parse output.
> consumers can use `wardlib.tools.out` (or their own parsing) on the `:output()`
> result.

## Import

```lua
local Sha256sum = require("wardlib.app.sha256sum").Sha256sum
```

## API

### `Sha256sum.bin`

Executable name or path (default: `"sha256sum"`).

### `Sha256sum.sum(files, opts)`

Builds: `sha256sum <opts...> [-- <files...>]`

- If `files` is `nil`, `sha256sum` reads stdin.
- If `files` is provided, the wrapper inserts `--` before the file list.

### `Sha256sum.check(check_files, opts)`

Builds: `sha256sum -c <opts...> [-- <check_files...>]`

- If `check_files` is `nil`, `sha256sum` reads the checksum list from stdin.
- If `check_files` is provided, the wrapper inserts `--` before the file list.

### `Sha256sum.raw(argv, opts)`

Builds: `sha256sum <opts...> <argv...>`

Use this when you need sha256sum options not modeled in `Sha256sumOpts`.

## Options (`Sha256sumOpts`)

- `binary: boolean?` → `-b` (binary mode)
- `text: boolean?` → `-t` (text mode)
  - Mutually exclusive: `binary` and `text`.
- `tag: boolean?` → `--tag`
- `zero: boolean?` → `-z` (NUL line terminator)

Check-mode options (when using `Sha256sum.check` / `-c`):

- `quiet: boolean?` → `--quiet`
- `status: boolean?` → `--status`
- `warn: boolean?` → `--warn`
- `strict: boolean?` → `--strict`
- `ignore_missing: boolean?` → `--ignore-missing`

Escape hatch:

- `extra: string[]?` → appended after modeled options

## Examples

### Compute hashes for files

```lua
local Sha256sum = require("wardlib.app.sha256sum").Sha256sum

-- sha256sum -- file1 file2
local cmd = Sha256sum.sum({ "file1", "file2" })
cmd:run()
```

### Parse the hash from stdout

```lua
local Sha256sum = require("wardlib.app.sha256sum").Sha256sum
local out = require("wardlib.tools.out")

local text = out.cmd(Sha256sum.sum("file1"))
  :label("sha256sum file1")
  :trim()
  :line()

-- Default format: "<hash>  <filename>"
local hash = text:match("^(%x+)%s")
assert(hash ~= nil, "failed to parse sha256")
```

### Verify checksums

```lua
local Sha256sum = require("wardlib.app.sha256sum").Sha256sum

-- sha256sum -c --strict -- checksums.txt
local cmd = Sha256sum.check("checksums.txt", { strict = true })
cmd:run()
```

### Read checksum list from stdin

```lua
local proc = require("ward.process")
local Sha256sum = require("wardlib.app.sha256sum").Sha256sum

-- printf '%s' "<hash>  file" | sha256sum -c
local feeder = proc.cmd("printf", "%s", "hello\n")
(feeder | Sha256sum.check(nil)):run()
```
