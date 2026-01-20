# app.ls

`app.ls` is a thin command-construction wrapper around the `ls` binary.
It returns `ward.process.cmd(...)` objects.

> This module constructs `ward.process.cmd(...)` invocations; it does not parse output.
> consumers can use `wardlib.tools.out` (or their own parsing) on the `:output()`
> result.

## Import

```lua
local Ls = require("wardlib.app.ls").Ls
```

## Options: `LsOpts`

- `all: boolean?` — `-a`
- `almost_all: boolean?` — `-A` (mutually exclusive with `all`)
- `long: boolean?` — `-l`
- `human: boolean?` — `-h` (GNU; typically used with `-l`)
- `classify: boolean?` — `-F`
- `one_per_line: boolean?` — `-1`
- `recursive: boolean?` — `-R`
- `directory: boolean?` — `-d` (list directories themselves, not contents)
- `reverse: boolean?` — `-r`

Sorting (mutually exclusive):

- `sort_time: boolean?` — `-t`
- `sort_size: boolean?` — `-S` (GNU)
- `no_sort: boolean?` — `-U` (BSD); GNU uses `-f` (use `extra` for portability)

GNU-only formatting:

- `color: 'auto'|'always'|'never'?` — `--color=<mode>`
- `time_style: string?` — `--time-style=<style>`

Extra:

- `extra: string[]?` — appended after modeled options

## API

### `Ls.list(paths, opts)`

List directory contents.

Builds: `ls <opts...> -- [paths...]`

```lua
Ls.list(paths: string|string[]|nil, opts: LsOpts|nil) -> ward.Cmd
```

Notes:

- If `paths` is `nil`, defaults to `{ "." }`.

### `Ls.raw(argv, opts)`

Low-level escape hatch.

Builds: `ls <modeled-opts...> <argv...>`

```lua
Ls.raw(argv: string|string[], opts: LsOpts|nil) -> ward.Cmd
```

## Examples

### Long listing with human-readable sizes

```lua
-- ls -lh -- /var/log
Ls.list("/var/log", { long = true, human = true }):run()
```

### List one entry per line and parse output

```lua
local out = require("wardlib.tools.out")

local files = out.cmd(Ls.list(".", { one_per_line = true }))
  :label("ls -1")
  :lines()
```

### Recursive listing

```lua
-- ls -R -- ./src
Ls.list("./src", { recursive = true }):run()
```

### Use extra flags for platform-specific behavior

```lua
-- GNU: ls -f (do not sort)
Ls.list(".", { extra = { "-f" } }):run()

-- BSD/macOS color flags differ; use extra for portability as needed.
```
