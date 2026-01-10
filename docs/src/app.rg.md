# rg

`rg` (ripgrep) is a fast recursive search tool that respects ignore files by default.

> This wrapper constructs a `ward.process.cmd(...)` invocation; it does not
> parse output.

## Import

```lua
local Rg = require("app.rg").Rg
```

## API

### `Rg.search(pattern, paths, opts)`

Builds: `rg <opts...> -e <pattern>... [paths...]`

- `pattern`: `string|string[]`
  - Always emitted using `-e <pattern>` (possibly repeated).
- `paths`: `string|string[]|nil`
  - If `nil`, ripgrep searches the current directory.

### `Rg.files(paths, opts)`

Builds: `rg <opts...> --files [paths...]`

### `Rg.raw(argv, opts)`

Builds: `rg <opts...> <argv...>`

Use this when you need an rg feature not modeled in `RgOpts`.

## Options (`RgOpts`)

Core matching:

- `fixed` (`-F`)
- `ignore_case` (`-i`), `smart_case` (`-S`), `case_sensitive` (`-s`)
- `word` (`-w`), `line` (`-x`), `invert` (`-v`)

Output and formatting:

- `count` (`-c`), `count_matches` (`--count-matches`)
- `quiet` (`-q`)
- `line_number` (`-n`), `column` (`--column`)
- `heading` (`--heading`)
- `no_filename` (`--no-filename`), `with_filename` (`--with-filename`) -
mutually exclusive
- `vimgrep` (`--vimgrep`), `json` (`--json`)

Context and limits:

- `after_context` (`-A <n>`), `before_context` (`-B <n>`)
- `context` (`-C <n>`) — mutually exclusive with `after_context/before_context`
- `max_count` (`-m <n>`)
- `threads` (`-j <n>`)

Filesystem behavior:

- `follow` (`-L`), `hidden` (`--hidden`)
- `no_ignore` (`--no-ignore`), `no_ignore_vcs` (`--no-ignore-vcs`)

Filtering:

- `glob` (`-g <glob>`) repeatable
- `type` (`--type <type>`) repeatable
- `type_not` (`--type-not <type>`) repeatable
- `files_with_matches` (`--files-with-matches`)
- `files_without_match` (`--files-without-match`)

Replacement:

- `replace` (`-r <replacement>`)

Other:

- `color` (`--color[=WHEN]`): `true` maps to `--color=auto`.
- `extra`: appended verbatim after modeled options.

## Examples

```lua
local Rg = require("app.rg").Rg

-- rg -F -S --hidden -g '*.lua' -g '!vendor/**' --type lua -C 2 --color=never -e TODO . src
local cmd = Rg.search("TODO", { ".", "src" }, {
  fixed = true,
  smart_case = true,
  hidden = true,
  glob = { "*.lua", "!vendor/**" },
  type = "lua",
  context = 2,
  color = "never",
})

-- rg -L --hidden --files .
local files = Rg.files(".", { follow = true, hidden = true })
```
