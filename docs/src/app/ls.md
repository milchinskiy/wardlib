# ls

`ls` lists directory contents.

> This wrapper constructs a `ward.process.cmd(...)` invocation; it does not
> parse output.

Notes:

- `ls` option sets differ across GNU/BSD/macOS. This wrapper models a
conservative core and provides `extra` for everything else.
- The wrapper always inserts `--` before paths.

## Import

```lua
local Ls = require("wardlib.app.ls").Ls
```

## API

### `Ls.list(paths, opts)`

Builds: `ls <opts...> -- [paths...]`

If `paths` is nil, defaults to `{"."}`.

### `Ls.raw(argv, opts)`

Builds: `ls <opts...> <argv...>`

## Options (`LsOpts`)

Common fields:

- Visibility: `all (-a)` or `almost_all (-A)` (mutually exclusive)
- Format: `long (-l)`, `human (-h)`, `classify (-F)`, `one_per_line (-1)`
- Traversal: `recursive (-R)`, `directory (-d)`
- Sorting: `sort_time (-t)`, `sort_size (-S)`, `no_sort (-U)` (mutually exclusive)
- Misc: `reverse (-r)`
- GNU-only: `color` (`--color=<mode>`), `time_style` (`--time-style=<style>`) -
use `extra` on BSD/macOS.
- Escape hatch: `extra`

## Examples

```lua
local Ls = require("wardlib.app.ls").Ls

-- ls -a -l -- .
local cmd1 = Ls.list(nil, { all = true, long = true })

-- ls -t -- /var/log
local cmd2 = Ls.list("/var/log", { sort_time = true })
```
