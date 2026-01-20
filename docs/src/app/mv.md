# app.mv

`app.mv` is a thin command-construction wrapper around the `mv` binary.
It returns `ward.process.cmd(...)` objects.

> This module constructs `ward.process.cmd(...)` invocations; it does not parse output.
> consumers can use `wardlib.tools.out` (or their own parsing) on the `:output()`
> result.

## Import

```lua
local Mv = require("wardlib.app.mv").Mv
```

## Privilege escalation

Moving files into protected locations may require elevated privileges. Prefer
`wardlib.tools.with` so escalation is explicit and scoped.

```lua
local with = require("wardlib.tools.with")

with.with(with.middleware.sudo(), function()
  Mv.move("./app.conf", "/etc/myapp/app.conf", { force = true }):run()
end)
```

## Options: `MvOpts`

Overwrite / interaction:

- `force: boolean?` — `-f` (mutually exclusive with `interactive`)
- `interactive: boolean?` — `-i`
- `no_clobber: boolean?` — `-n` (GNU; mutually exclusive with `force/interactive`)

Other behavior:

- `update: boolean?` — `-u`
- `verbose: boolean?` — `-v`

GNU-only:

- `backup: boolean?` — `--backup`
- `suffix: string?` — `--suffix=<s>`
- `target_directory: string?` — `-t <dir>`
- `no_target_directory: boolean?` — `-T`

Extra:

- `extra: string[]?` — appended after modeled options

## API

### `Mv.move(src, dest, opts)`

Move one or more sources to a destination.

Builds: `mv <opts...> -- <src...> <dest>`

```lua
Mv.move(src: string|string[], dest: string, opts: MvOpts|nil) -> ward.Cmd
```

### `Mv.into(src, dir, opts)`

Move one or more sources into a directory using GNU-style `-t`.

Builds: `mv <opts...> -t <dir> -- <src...>`

```lua
Mv.into(src: string|string[], dir: string, opts: MvOpts|nil) -> ward.Cmd
```

Notes:

- `-t` is GNU-style. If your platform does not support it, prefer
`Mv.move(src, dir, ...)`.

### `Mv.raw(argv, opts)`

Low-level escape hatch.

Builds: `mv <modeled-opts...> <argv...>`

```lua
Mv.raw(argv: string|string[], opts: MvOpts|nil) -> ward.Cmd
```

## Examples

### Move a file

```lua
-- mv -- a.txt b.txt
Mv.move("a.txt", "b.txt"):run()
```

### Move multiple files into a directory

```lua
-- mv -- a.txt b.txt ./dst
Mv.move({ "a.txt", "b.txt" }, "./dst"):run()
```

### Use GNU `-t` (move into)

```lua
-- mv -t ./dst -- a.txt b.txt
Mv.into({ "a.txt", "b.txt" }, "./dst"):run()
```

### Prevent overwrite (GNU)

```lua
-- mv -n -- a.txt ./dst/a.txt
Mv.move("a.txt", "./dst/a.txt", { no_clobber = true }):run()
```
