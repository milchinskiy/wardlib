# rg

`rg` (**ripgrep**) is a fast recursive search tool that respects ignore files
by default.

> This module constructs `ward.process.cmd(...)` invocations; it does not parse output.
> consumers can use `wardlib.tools.out` (or their own parsing) on the `:output()`
> result.

## Import

```lua
local Rg = require("wardlib.app.rg").Rg
```

## Exit codes

`rg` uses exit codes that often surprise users:

- **0**: at least one match was found
- **1**: no matches were found
- **2**: an error occurred

When you want “no matches” to be a non-failure, use `wardlib.tools.out` with
`:allow_fail()` and interpret `res.code`.

## API

### `Rg.bin`

Executable name or path (default: `"rg"`).

### `Rg.search(pattern, paths, opts)`

Builds: `rg <opts...> -e <pattern>... [paths...]`

- `pattern`: `string|string[]`
  - Always emitted using `-e <pattern>` (possibly repeated) to avoid ambiguity
    when patterns start with `-`.
- `paths`: `string|string[]|nil`
  - If `nil`, ripgrep searches the current directory.

### `Rg.files(paths, opts)`

Builds: `rg <opts...> --files [paths...]`

### `Rg.raw(argv, opts)`

Builds: `rg <opts...> <argv...>`

Use this when you need an rg feature not modeled in `RgOpts`.

## Options

### `RgOpts`

Matching behavior:

- `fixed: boolean?` → `-F` (fixed strings)
- `ignore_case: boolean?` → `-i`
- `smart_case: boolean?` → `-S`
- `case_sensitive: boolean?` → `-s`
- `word: boolean?` → `-w`
- `line: boolean?` → `-x`
- `invert: boolean?` → `-v`

Output / formatting:

- `count: boolean?` → `-c` (count matching lines)
- `count_matches: boolean?` → `--count-matches`
- `quiet: boolean?` → `-q`
- `line_number: boolean?` → `-n`
- `column: boolean?` → `--column`
- `heading: boolean?` → `--heading`
- `no_filename: boolean?` → `--no-filename` (mutually exclusive with `with_filename`)
- `with_filename: boolean?` → `--with-filename` (mutually exclusive with `no_filename`)
- `vimgrep: boolean?` → `--vimgrep`
- `json: boolean?` → `--json` (JSON Lines / NDJSON)

Context / limits:

- `after_context: number?` → `-A <n>`
- `before_context: number?` → `-B <n>`
- `context: number?` → `-C <n>` (mutually exclusive with `after_context/before_context`)
- `max_count: number?` → `-m <n>`
- `threads: number?` → `-j <n>`

Filesystem behavior:

- `follow: boolean?` → `-L` (follow symlinks)
- `hidden: boolean?` → `--hidden`
- `no_ignore: boolean?` → `--no-ignore`
- `no_ignore_vcs: boolean?` → `--no-ignore-vcs`

Filtering:

- `glob: string|string[]?` → `-g <glob>` (repeatable)
- `type: string|string[]?` → `--type <type>` (repeatable)
- `type_not: string|string[]?` → `--type-not <type>` (repeatable)
- `files_with_matches: boolean?` → `--files-with-matches`
- `files_without_match: boolean?` → `--files-without-match`

Replacement:

- `replace: string?` → `-r <replacement>`

Other:

- `color: boolean|string?` → `--color[=WHEN]`
  - If `true`, emits `--color=auto`.
  - If a string, emits `--color=<value>`.
- `extra: string[]?` → extra argv appended after modeled options

## Examples

### Basic search

```lua
local Rg = require("wardlib.app.rg").Rg

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

cmd:run()
```

### Treat “no matches” as non-failure

```lua
local Rg = require("wardlib.app.rg").Rg
local out = require("wardlib.tools.out")

local o = out.cmd(Rg.search("needle", ".", { fixed = true }))
  :label("rg search")
  :allow_fail()

local res = o:res()  -- access the underlying CmdResult

if res.code == 0 then
  local lines = out.res(res):lines()
  -- matches present
elseif res.code == 1 then
  -- no matches (not an error)
else
  -- res.code == 2 (or other) – treat as error
  error("rg failed: " .. tostring(res.code))
end
```

### Parse `--json` output (NDJSON)

```lua
local Rg = require("wardlib.app.rg").Rg
local out = require("wardlib.tools.out")

local events = out.cmd(Rg.search("TODO", ".", { json = true }))
  :label("rg --json")
  :json_lines()

-- events is an array of decoded JSON objects (one per line)
-- You can filter for { type = "match" } events, etc.
```

### List files ripgrep would search

```lua
local Rg = require("wardlib.app.rg").Rg

-- rg --files .
local cmd = Rg.files(".")
cmd:run()
```
