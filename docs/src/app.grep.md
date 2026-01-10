# grep

`grep` searches text for regular expressions (or fixed strings).

> This wrapper constructs a `ward.process.cmd(...)` invocation; it does
> not parse output.

## Import

```lua
local Grep = require("app.grep").Grep
```

## API

### `Grep.search(pattern, inputs, opts)`

Builds: `grep <opts...> -e <pattern>... [inputs...]`

- `pattern`: `string|string[]`
  - Always emitted using `-e <pattern>` (possibly repeated), which avoids
  ambiguity when patterns start with `-`.
- `inputs`: `string|string[]|nil`
  - If `nil`, grep reads stdin.

### `Grep.count_matches(pattern, inputs, opts)`

Builds: `grep <opts...> -c -e <pattern>... [inputs...]`

### `Grep.list_files(pattern, inputs, opts)`

Builds: `grep <opts...> -l -e <pattern>... [inputs...]`

### `Grep.raw(argv, opts)`

Builds: `grep <opts...> <argv...>`

Use this when you need a flag or submode not modeled in `GrepOpts`.

## Options (`GrepOpts`)

Core matching:

- `extended` (`-E`), `fixed` (`-F`), `perl` (`-P`) — mutually exclusive.
- `ignore_case` (`-i`), `word` (`-w`), `line` (`-x`), `invert` (`-v`)

Output / selection:

- `count` (`-c`), `quiet` (`-q`)
- `line_number` (`-n`)
- `files_with_matches` (`-l`), `files_without_matches` (`-L`)
- `with_filename` (`-H`), `no_filename` (`-h`) — mutually exclusive.

Recursion:

- `recursive` (`-r`), `recursive_follow` (`-R`) — mutually exclusive.

Context and limits:

- `max_count` (`-m <n>`)
- `after_context` (`-A <n>`), `before_context` (`-B <n>`)
- `context` (`-C <n>`) — mutually exclusive with `after_context/before_context`.

Binary / NUL:

- `null` (`-Z`), `null_data` (`-z`, GNU)
- `text` (`-a`), `binary_without_match` (`-I`)

GNU-specific convenience:

- `color` (`--color[=WHEN]`): `true` maps to `--color=auto`.
- `include`, `exclude`, `exclude_dir`: add `--include=...`, `--exclude=...`, `--exclude-dir=...`.

Other:

- `extra`: appended verbatim after modeled options.

## Examples

```lua
local Grep = require("app.grep").Grep

-- grep -E -i -n -A 2 --color=auto --include=*.txt -e foo -e bar a.txt b.txt
local cmd = Grep.search({ "foo", "bar" }, { "a.txt", "b.txt" }, {
  extended = true,
  ignore_case = true,
  line_number = true,
  after_context = 2,
  color = true,
  include = "*.txt",
})

-- grep -F -c -e needle file
local count = Grep.count_matches("needle", "file", { fixed = true })
```
