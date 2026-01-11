# sha256sum

`sha256sum` computes and checks SHA-256 message digests.

> This wrapper constructs a `ward.process.cmd(...)` invocation; it does not
> parse output.

## Import

```lua
local Sha256sum = require("app.sha256sum").Sha256sum
```

## API

### `Sha256sum.sum(files, opts)`

Builds: `sha256sum <opts...> [-- <files...>]`

- If `files` is `nil`, sha256sum reads stdin.
- If `files` is provided, the wrapper inserts `--` before the file list.

### `Sha256sum.check(check_files, opts)`

Builds: `sha256sum -c <opts...> [-- <check_files...>]`

- If `check_files` is `nil`, sha256sum reads the checksum list from stdin.
- If `check_files` is provided, the wrapper inserts `--` before the file list.

### `Sha256sum.raw(argv, opts)`

Builds: `sha256sum <opts...> <argv...>`

Use this when you need sha256sum options not modeled in `Sha256sumOpts`.

## Options (`Sha256sumOpts`)

Modeled fields:

- Input mode: `binary (-b)` or `text (-t)` (mutually exclusive)
- Output formatting: `tag (--tag)`, `zero (-z)`
- Check-mode behavior: `quiet (--quiet)`, `status (--status)`, `warn (--warn)`,
`strict (--strict)`, `ignore_missing (--ignore-missing)`
- Escape hatch: `extra`

## Examples

```lua
local Sha256sum = require("app.sha256sum").Sha256sum

-- sha256sum -- file1 file2
local cmd1 = Sha256sum.sum({ "file1", "file2" })

-- sha256sum -c --strict -- checksums.txt
local cmd2 = Sha256sum.check("checksums.txt", { strict = true })

-- sha256sum reads stdin (useful with ward.process piping)
local cmd3 = Sha256sum.sum(nil)
```
