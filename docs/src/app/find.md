# find

`find` walks directory trees and evaluates an expression against each entry.

> This wrapper constructs a `ward.process.cmd(...)` invocation; it does not
> parse output.

Notes:

- `find` variants (GNU/BSD/BusyBox) differ. Use `expr` / `extra_expr` to access
unmodeled features.
- Traversal mode flags `-P`, `-L`, `-H` must be placed before the paths; this
wrapper enforces that.

## Import

```lua
local Find = require("wardlib.app.find").Find
```

## API

### `Find.run(paths, expr, opts)`

Builds: `find [(-P|-L|-H)] <extra...> -- [paths...] <modeled-expr...> <expr...>`

- `paths`: `string|string[]|nil`
  - If `nil`, defaults to `{"."}`.
- `expr`: `string|string[]|nil`
  - Additional expression tokens appended after the modeled expression.
- `opts`: `FindOpts|nil`

### `Find.search(paths, opts)`

Convenience for `Find.run(paths, nil, opts)`.

### `Find.raw(argv, opts)`

Builds: `find <modeled-start-opts...> <argv...>`

Use this when you need full control over parsing.

## Options (`FindOpts`)

Modeled fields:

- Traversal mode: `follow_mode` (`'P'|'L'|'H'`)
- Common traversal controls: `maxdepth`, `mindepth`, `xdev`, `depth`
- Common tests: `type`, `name`, `iname`, `path`, `ipath`, `regex`, `iregex`,
`size`, `user`, `group`, `perm`, `mtime`, `atime`, `ctime`, `newer`, `empty`,
`readable`, `writable`, `executable`
- Action: `print0` (otherwise find defaults to `-print`)
- Escape hatches: `extra` (before `--`) and `extra_expr` (after modeled expression)

## Examples

```lua
local Find = require("wardlib.app.find").Find

-- find -- . -maxdepth 1 -type f -name '*.lua' -print0
local cmd1 = Find.search(".", {
  maxdepth = 1,
  type = "f",
  name = "*.lua",
  print0 = true,
})

-- find -L -- /var/log -xdev -name '*.log' -print
local cmd2 = Find.run("/var/log", { "-name", "*.log", "-print" }, {
  follow_mode = "L",
  xdev = true,
})
```
