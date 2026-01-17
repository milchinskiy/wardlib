# tools.cli

`tools.cli` provides a small, Ward-native command-line argument parser for Lua scripts.

It is designed for:

- Declarative option/argument definitions (data-first spec).
- Common GNU-style flag forms: `--long`, `--long=value`, `--long value`, `-s`, `-svalue`, and short bundles like `-abc`.
- Automatic help generation (`-h` / `--help`).
- Optional version output (`--version` / `-V`).
- Optional subcommands (including nesting).
- Subcommand aliases (via `subcommand.aliases`).
- Grouped option sections in help (via `option.group`).
- Examples and an epilog section in help (via `spec.examples` and `spec.epilog`).
- Subcommand help inherits parent `examples` when the subcommand does not define its own examples.
- No side effects: it does not use `io` and it does not exit the process; it returns structured results/errors.

## Quick example

```lua
local cli = require("wardlib.tools.cli")

local parser = cli.new({
  name = "mytool",
  version = "1.2.3",
  summary = "Example tool",

  options = {
    { id = "verbose", short = "v", long = "verbose", kind = "count", help = "Increase verbosity" },
    { id = "config",  short = "c", long = "config",  kind = "value", metavar = "FILE", help = "Config file" },
    { id = "dry_run", long = "dry-run", kind = "flag", help = "Do not apply changes" },
  },

  positionals = {
    { id = "input", metavar = "INPUT", kind = "value", required = true, help = "Input file" },
    { id = "rest",  metavar = "ARGS",  kind = "values", variadic = true, help = "Extra args" },
  },
}, { auto_version = true })

local ok, out = parser:parse() -- defaults to global `arg`
if not ok then
  -- out.code may be "help" or "version" (non-error exits), or an error code.
  print(out.text)
  return
end

print(out.values.verbose)
print(out.values.config)
print(out.positionals.input)
```

## Subcommands example

```lua
local cli = require("wardlib.tools.cli")

local parser = cli.new({
  name = "mytool",
  summary = "Tool with subcommands",

  subcommands = {
    {
      name = "run",
      summary = "Run the tool",
      options = {
        { id = "jobs", short = "j", long = "jobs", kind = "value", type = "int", default = 1, metavar = "N" },
      },
      positionals = {
        { id = "target", metavar = "TARGET", kind = "value", required = true },
      },
    },
  },
})

local ok, out = parser:parse({ [0] = "mytool", "run", "--jobs", "4", "all" })
assert(ok)

-- Root values/positionals are in out.values / out.positionals.
-- Selected command details are in out.cmd.
print(out.cmd.name)               -- "run"
print(out.cmd.values.jobs)        -- 4
print(out.cmd.positionals.target) -- "all"
```

## API

### `cli.new(spec, opts?) -> parser`

Creates a parser.

`opts`:

- `auto_help` (boolean, default `true`): injects `-h/--help` if not defined.
- `auto_version` (boolean, default `false`): injects `--version/-V` if not defined.

### `parser:parse(argv?, parse_opts?) -> (ok, result_or_err)`

Parses arguments.

- `argv`:
  - `nil` (default): reads `_G.arg`.
  - `{"--foo", "bar"}`: array form.
  - `{ [0] = "script.lua", "--foo", "bar" }`: Lua `arg`-like form.

`parse_opts`:

- `start_index` (number, default `1`): where to begin reading `argv`.
- `allow_unknown` (boolean, default `false`): if true, unknown options are appended to `result.rest`.
- `stop_at_first_positional` (boolean, default `false`): if true, once a positional is seen, the remaining tokens are treated as positional/rest.
- `on_event(event, state)` (function|nil): event callback.

Return values:

- On success: `ok=true`, and `result`:
  - `result.values` (table): parsed option values by `id`.
  - `result.positionals` (table): parsed positional values by `id`.
  - `result.rest` (array): remaining/unconsumed tokens (when allowed).
  - `result.cmd` (table|nil): selected subcommand parse (when subcommands are defined).
  - `result.argv0` (string): program/script name when available.

- On failure/help/version: `ok=false`, and `err`:
  - `err.code` (string): e.g. `"help"`, `"version"`, `"unknown_option"`, `"missing_value"`, `"invalid_value"`, `"missing_required"`, `"unknown_command"`, `"option_repeated"`, `"too_many_occurrences"`, `"mutually_exclusive"`, `"missing_one_of"`.
  - `err.message` (string)
  - `err.token` (string|nil)
  - `err.text` (string): formatted message plus usage/help.

### `parser:usage() -> string`

Returns a single-line usage string.

### `parser:help(help_opts?) -> string`

Returns a multi-section help string.

`help_opts`:

- `width` (number, default `100`)
- `include_description` (boolean, default `true`)
- `include_defaults` (boolean, default `true`)

## Help formatting

Help output is deterministic and organized into sections. Options may be grouped by setting `group` on each option.

When subcommands are used, auto-injected `--help/-h` and `--version/-V` are displayed under **Common options** if you define at least one explicit option group.

If `spec.examples` is provided, an **Examples** section is appended. For subcommands, if the subcommand does not define `examples`, the parent command's examples are used (inheritance). If the subcommand defines `examples`, they override the parent examples.

If `spec.epilog` is provided, it is appended after all other sections.

`examples` entries may be:

- a string command line (printed verbatim), or
- a table `{ cmd = "...", desc = "..." }` (or `{ "...", "..." }`)

## Spec schema

### Top-level fields

- `name` (string, required): program name used in usage/help.
- `summary` (string|nil): one-line description.
- `description` (string|nil): longer description.
- `version` (string|nil): version string (used by `--version` when `auto_version=true`).
- `options` (array|nil): root options.
- `positionals` (array|nil): root positionals.
- `subcommands` (array|nil): list of subcommands.

- `examples` (array|nil): help examples (strings or `{cmd, desc}` tables).
- `epilog` (string|nil): additional text appended to help.

- `constraints` (table|nil): extra validation rules applied after parsing. See **Constraints** below.

### Options

Each element of `spec.options` is a table:

- `id` (string, required): key in `result.values`.
- `long` (string|nil): `--long` name (without `--`).
- `short` (string|nil): single-letter `-s`.
- `kind` (string, default `"flag"`):
  - `"flag"`: boolean
  - `"count"`: increments per occurrence
  - `"value"`: consumes one value
  - `"values"`: consumes one value per occurrence into an array
- `type` (string, default `"string"`): `"string" | "number" | "int" | "enum"`
- `choices` (array, enum only): allowed values
- `default` (any|nil)
- `required` (boolean|nil)
- `metavar` (string|nil): label shown in help for value options
- `group` (string|nil): option help section heading (default: `"Options"`).
- `help` (string|nil)

- `negatable` (boolean|nil): for `kind="flag"` only. If true, `--no-<long>` is accepted and sets the flag to `false`.
- `repeatable` (boolean, default `true`): if set to `false`, repeating the option produces an `option_repeated` error (applies to `flag`, `value`, and `count`).
- `max_count` (number|nil): for `kind="count"` only. If set, exceeding the limit produces a `too_many_occurrences` error.
- `validate(value)` (function|nil): custom validator; return `true` on success, or `false, reason` to reject. A thrown error is surfaced as an `invalid_value` error.

- `on(value, event, state)` (function|nil): called after parsing/coercion

### Positionals

Each element of `spec.positionals` is a table:

- `id` (string, required)
- `metavar` (string, required)
- `kind` (string, default `"value"`): `"value" | "values"`
- `type` (string, default `"string"`)
- `required` (boolean|nil)
- `variadic` (boolean|nil): only valid for the last positional; consumes remaining tokens
- `help` (string|nil)

- `validate(value)` (function|nil): custom validator; return `true` on success, or `false, reason` to reject.
- `on(value, event, state)` (function|nil)

### Constraints

`spec.constraints` is optional and supports:

- `mutex` (array of groups): each group is an array of option `id`s that are mutually exclusive. If more than one is present, parsing fails with `code="mutually_exclusive"`.
- `one_of` (array of groups): each group is an array of option `id`s where at least one must be present. If none are present, parsing fails with `code="missing_one_of"`.

Example:

```lua
constraints = {
  mutex = { { "json", "yaml" } },
  one_of = { { "input", "stdin" } },
}
```

### Subcommands

Each element of `spec.subcommands` is a table:

- `name` (string, required)
- `summary` (string|nil)
- `description` (string|nil)
- `options` (array|nil)
- `positionals` (array|nil)
- `subcommands` (array|nil): nested subcommands

- `aliases` (string|array|nil): alternative tokens that invoke this command (e.g. `{ "r", "execute" }`).

When a subcommand is selected, parsing continues with that subcommand spec. The nested parse result is returned in `result.cmd`.
