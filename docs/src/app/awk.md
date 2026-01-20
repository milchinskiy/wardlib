# awk

Thin wrapper around `awk` (and `gawk`-style extensions) that constructs
`ward.process.cmd(...)` invocations.

> This module constructs `ward.process.cmd(...)` invocations; it does not parse output.
> consumers can use `wardlib.tools.out` (or their own parsing) on the `:output()`
> result.

## Import

```lua
local Awk = require("wardlib.app.awk").Awk
```

## Privilege escalation

This module does not implement `sudo`/`doas` options. Use `wardlib.tools.with`
middleware when needed.

## API

### `Awk.bin`

Executable name or path used for `awk`.

### `Awk.cmd(argv)`

Low-level escape hatch.

Builds: `awk <argv...>`

- `argv: string[]|nil` — raw argv (without the `awk` binary).

### `Awk.eval(program, inputs, opts)`

Inline program mode.

Builds: `awk <opts...> <program> <assigns...> <inputs...>`

- `program: string` — inline awk program.
- `inputs: string|string[]|nil` — input file(s). When `nil`, awk reads stdin.
- `opts: AwkOpts|nil` — modeled options.

### `Awk.source(programs, inputs, opts)`

Multiple inline programs.

Builds: `awk <opts...> -e <p1> -e <p2> ... <assigns...> <inputs...>`

- `programs: string|string[]` — one or more programs.

### `Awk.file(scripts, inputs, opts)`

Script file mode.

Builds: `awk <opts...> -f <file1> -f <file2> ... <assigns...> <inputs...>`

- `scripts: string|string[]` — one or more `.awk` script paths.

## Options (`AwkOpts`)

General:

- `field_sep: string|nil` — `-F <sep>`.
- `vars: table|nil` — `-v name=value` repeated. Accepts:
  - array form: `{ "k=v", "x=1" }`
  - map form: `{ k = "v", x = 1 }` (sorted by key for deterministic argv)
- `assigns: table|nil` — post-program assignments `name=value`
(array or map; map is sorted by key).
- `includes: string[]|nil` — gawk: `-i <file>` repeated.
- `extra: string[]|nil` — extra args appended **before** the program/scripts.

Boolean long flags (mostly gawk):

- `posix` (`--posix`)
- `traditional` (`--traditional`)
- `lint` (`--lint`)
- `interval` (`--interval`)
- `bignum` (`--bignum`)
- `sandbox` (`--sandbox`)
- `csv` (`--csv`)
- `optimize` (`--optimize`)
- `ignore_case` (`--ignore-case`)
- `characters_as_bytes` (`--characters-as-bytes`)
- `use_lc_numeric` (`--use-lc-numeric`)

Optional-value long flags (true => flag only; string => `--flag=<value>`):

- `debug` — gawk: `--debug[=flags]`
- `profile` — gawk: `--profile[=file]`
- `pretty_print` — gawk: `--pretty-print[=file]`
- `dump_variables` — gawk: `--dump-variables[=file]`

## Examples

### Inline program

```lua
local Awk = require("wardlib.app.awk").Awk

-- awk -F: '{print $1}' /etc/passwd
local cmd = Awk.eval("{print $1}", "/etc/passwd", {
  field_sep = ":",
})
```

### With variables (`-v`) and assignments

```lua
local Awk = require("wardlib.app.awk").Awk

-- awk -v a=x -v b=2 '{print a, b, $1}' y=t z=9 /etc/passwd
local cmd = Awk.eval("{print a, b, $1}", "/etc/passwd", {
  vars = { a = "x", b = 2 },
  assigns = { y = "t", z = 9 },
})
```

Notes:

- `vars` (`-v`) are applied before the program.
- `assigns` (`name=value`) are appended after the program (and before inputs).

### Multiple programs (`-e`)

```lua
local Awk = require("wardlib.app.awk").Awk

-- awk -e 'BEGIN{a=1}' -e '{print a}' input.txt
local cmd = Awk.source({ "BEGIN{a=1}", "{print a}" }, "input.txt")
```

### Script files (`-f`)

```lua
local Awk = require("wardlib.app.awk").Awk

-- awk -f a.awk -f b.awk input.txt
local cmd = Awk.file({ "a.awk", "b.awk" }, "input.txt")
```

### Parse stdout as lines

```lua
local Awk = require("wardlib.app.awk").Awk
local out = require("wardlib.tools.out")

local res = Awk.eval("{print $1}", "/etc/passwd"):output()
local lines = out.res(res):ok():lines()
```
