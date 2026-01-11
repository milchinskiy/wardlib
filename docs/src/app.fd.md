# fd

`fd` is a simple, fast and user-friendly alternative to `find`.

> This wrapper constructs a `ward.process.cmd(...)` invocation; it does
> not parse output.

## Import

```lua
local Fd = require("app.fd").Fd
```

## API

### `Fd.search(pattern, paths, opts)`

Builds: `fd <opts...> [pattern] [paths...]`

- `pattern`: `string|nil`
  - If `nil`, defaults to `"."`.
  - If you want to match all entries explicitly, you may also pass `""`.
- `paths`: `string|string[]|nil`
  - If `nil`, fd searches the current directory.

### `Fd.all(paths, opts)`

Convenience for `Fd.search(".", paths, opts)`.

### `Fd.raw(argv, opts)`

Builds: `fd <opts...> <argv...>`

Use this when you need an fd feature not modeled in `FdOpts`.

## Options (`FdOpts`)

Common fields:

- Ignore/visibility: `hidden (-H)`, `no_ignore (-I)`, `unrestricted (-u)`, `no_ignore_vcs`
- Traversal: `follow (-L)`, `max_depth (-d)`, `min_depth (--min-depth)`,
`exact_depth (--exact-depth)`
- Match mode: `glob (-g)`, `fixed_strings (-F)`
- Case: `case_sensitive (-s)`, `ignore_case (-i)`
- Filtering: `type (-t)`, `extension (-e)`, `exclude (-E)`, `size (-S)`,
`changed_within`, `changed_before`
- Output: `absolute_path (-a)`, `full_path (-p)`, `print0 (-0)`, `quiet (-q)`,
`show_errors`
- Actions: `exec (-x)`, `exec_batch (-X)` (mutually exclusive)
- Extra: `extra`

## Examples

```lua
local Fd = require("app.fd").Fd

-- fd -e lua -e md --hidden -- "" .
local cmd1 = Fd.search("", ".", {
  hidden = true,
  extension = { "lua", "md" },
})

-- fd -t f -E node_modules -d 3 needle .
local cmd2 = Fd.search("needle", ".", {
  type = "f",
  exclude = "node_modules",
  max_depth = 3,
})

-- fd -x echo {} (pass command tokens as array)
local cmd3 = Fd.search(".", nil, {
  exec = { "echo", "{}" },
})
```
