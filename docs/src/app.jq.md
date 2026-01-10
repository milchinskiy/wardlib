# jq

`jq` is a command-line JSON processor.

> This wrapper constructs a `ward.process.cmd(...)` invocation; it does not
> parse output.

## Import

```lua
local Jq = require("app.jq").Jq
```

## API

### `Jq.eval(filter, inputs, opts)`

Builds: `jq <opts...> -- <filter> [inputs...]`

- `filter`: `string|nil`
  - If `nil`, defaults to `"."`.
  - The wrapper always emits `--` before the filter to avoid ambiguity when a
  filter starts with `-`.
- `inputs`: `string|string[]|nil`
  - If `nil`, jq reads stdin.

### `Jq.eval_file(file, inputs, opts)`

Builds: `jq <opts...> -f <file> [inputs...]`

### `Jq.eval_stdin(filter, data, opts)`

Convenience over `Jq.eval(filter, nil, opts)` that attaches `data` to stdin.

### `Jq.raw(argv, opts)`

Builds: `jq <opts...> <argv...>`

Use this when you need a jq feature not modeled in `JqOpts`.

## Options (`JqOpts`)

Common fields:

- Input mode: `null_input (-n)`, `raw_input (-R)`, `slurp (-s)`
- Output formatting: `compact_output (-c)`, `raw_output (-r)`, `join_output (-j)`
- Color: `color_output (-C)`, `monochrome_output (-M)` (mutually exclusive)
- Determinism: `sort_keys (-S)`
- Exit behavior: `exit_status (-e)`
- Misc: `ascii_output (-a)`, `tab (--tab)`, `indent (--indent <n>)`
- Variables:
  - `arg`: emits `--arg <name> <value>`
  - `argjson`: emits `--argjson <name> <json>`
  - `slurpfile`: emits `--slurpfile <name> <file>`
  - `rawfile`: emits `--rawfile <name> <file>`
- Extra: `extra` (argv appended after modeled options and variables, before the filter)

Notes:

- Variable names are validated as identifiers: `^[A-Za-z_][A-Za-z0-9_]*$`.

## Examples

```lua
local Jq = require("app.jq").Jq

-- jq -r -- '.name' data.json
local cmd1 = Jq.eval(".name", "data.json", { raw_output = true })

-- jq -c -- '.items[] | select(.enabled) | .id' data.json
local cmd2 = Jq.eval(".items[] | select(.enabled) | .id", "data.json", {
  compact_output = true,
})

-- jq --arg key value -- '.[$key]' data.json
local cmd3 = Jq.eval(".[$key]", "data.json", {
  arg = { key = "value" },
})

-- Feed JSON via stdin (jq -c -- '.')
local cmd4 = Jq.eval_stdin(".", "{\"a\": 1}", { compact_output = true })
```
