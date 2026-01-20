# app.jq

`app.jq` is a thin command-construction wrapper around the `jq` binary.
It returns `ward.process.cmd(...)` objects.

> This module constructs `ward.process.cmd(...)` invocations; it does not parse output.
> consumers can use `wardlib.tools.out` (or their own parsing) on the `:output()`
> result.

## Import

```lua
local Jq = require("wardlib.app.jq").Jq
```

## Options: `JqOpts`

### Input

- `null_input: boolean?` — `-n` (use null input)
- `raw_input: boolean?` — `-R` (read raw strings, not JSON)
- `slurp: boolean?` — `-s` (read all inputs into a single array)

### Output formatting

- `compact_output: boolean?` — `-c`
- `raw_output: boolean?` — `-r`
- `join_output: boolean?` — `-j`
- `sort_keys: boolean?` — `-S`
- `monochrome_output: boolean?` — `-M`
- `color_output: boolean?` — `-C`
- `exit_status: boolean?` — `-e` (set exit status based on output)
- `ascii_output: boolean?` — `-a`
- `tab: boolean?` — `--tab`
- `indent: integer?` — `--indent <n>` (validated as integer `>= 0`)

Notes:

- `color_output` and `monochrome_output` are **mutually exclusive**.

### Variables

All variable maps are repeatable and are emitted in **stable-sorted** order for
predictable argv.

- `arg: table<string,string>?` — `--arg <name> <value>`
- `argjson: table<string,string>?` — `--argjson <name> <json>`
- `slurpfile: table<string,string>?` — `--slurpfile <name> <file>`
- `rawfile: table<string,string>?` — `--rawfile <name> <file>`

Variable names are validated as identifiers matching: `^[A-Za-z_][A-Za-z0-9_]*$`.

### Extra

- `extra: string[]?` — appended after modeled options (before the filter)

## API

### `Jq.eval(filter, inputs, opts)`

Builds: `jq <opts...> -- <filter> [inputs...]`

```lua
Jq.eval(filter: string|nil, inputs: string|string[]|nil, opts: JqOpts|nil) -> ward.Cmd
```

Semantics:

- If `filter` is `nil`, it defaults to `"."`.
- The wrapper always emits `--` before the filter to avoid ambiguity when a
  filter starts with `-`.
- If `inputs` is `nil`, jq reads stdin.

### `Jq.eval_file(file, inputs, opts)`

Builds: `jq <opts...> -f <file> [inputs...]`

```lua
Jq.eval_file(file: string, inputs: string|string[]|nil, opts: JqOpts|nil) -> ward.Cmd
```

### `Jq.eval_stdin(filter, data, opts)`

Convenience over `Jq.eval(filter, nil, opts)` that attaches `data` to stdin.

```lua
Jq.eval_stdin(filter: string|nil, data: string, opts: JqOpts|nil) -> ward.Cmd
```

### `Jq.raw(argv, opts)`

Low-level escape hatch.

Builds: `jq <opts...> <argv...>`

```lua
Jq.raw(argv: string|string[], opts: JqOpts|nil) -> ward.Cmd
```

## Examples

### Extract a field as a string

```lua
local out = require("wardlib.tools.out")

-- jq -r -- '.name' data.json
local name = out.cmd(Jq.eval(".name", "data.json", { raw_output = true }))
  :label("jq -r .name data.json")
  :trim()
  :line()
```

### Filter and print multiple values

```lua
-- jq -c -- '.items[] | select(.enabled) | .id' data.json
local res = Jq.eval(".items[] | select(.enabled) | .id", "data.json", { compact_output = true }):output()
-- res.stdout contains newline-delimited JSON scalars (strings/numbers)
```

### Use variables

```lua
-- jq --arg key value -- '.[$key]' data.json
local cmd = Jq.eval(".[$key]", "data.json", { arg = { key = "value" } })
```

### Feed JSON via stdin

```lua
local out = require("wardlib.tools.out")

-- jq -c -- '.'
local json = out.cmd(Jq.eval_stdin(".", "{\"a\": 1}", { compact_output = true }))
  :label("jq stdin")
  :text()
```
