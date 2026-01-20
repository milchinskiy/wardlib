# app.mkdir

`app.mkdir` is a thin command-construction wrapper around the `mkdir` binary.
It returns `ward.process.cmd(...)` objects.

> This module constructs `ward.process.cmd(...)` invocations; it does not parse output.
> consumers can use `wardlib.tools.out` (or their own parsing) on the `:output()`
> result.

## Import

```lua
local Mkdir = require("wardlib.app.mkdir").Mkdir
```

## Options: `MkdirOpts`

- `parents: boolean?` — `-p`
- `verbose: boolean?` — `-v`
- `mode: string?` — `-m <mode>`
- `dry_run: boolean?` — `--dry-run` (GNU)
- `extra: string[]?` — appended after modeled options

## API

### `Mkdir.make(paths, opts)`

Create one or more directories.

Builds: `mkdir <opts...> -- <paths...>`

```lua
Mkdir.make(paths: string|string[], opts: MkdirOpts|nil) -> ward.Cmd
```

### `Mkdir.raw(argv, opts)`

Low-level escape hatch.

Builds: `mkdir <modeled-opts...> <argv...>`

```lua
Mkdir.raw(argv: string|string[], opts: MkdirOpts|nil) -> ward.Cmd
```

## Examples

### Create nested directories

```lua
-- mkdir -p -- /var/lib/myapp/data
Mkdir.make("/var/lib/myapp/data", { parents = true }):run()
```

### Set directory mode

```lua
-- mkdir -m 0750 -- /var/lib/myapp
Mkdir.make("/var/lib/myapp", { mode = "0750" }):run()
```

### Dry-run (GNU)

```lua
-- mkdir --dry-run -p -- ./a/b
Mkdir.make("./a/b", { dry_run = true, parents = true }):run()
```
