# awk

Thin wrappers around `awk` that construct `ward.process.cmd(...)` invocations.

## Import

```lua
local Awk = require("app.awk").Awk
```

## Inline program

```lua
local Awk = require("app.awk").Awk

-- Equivalent to: awk -F: '{print $1}' /etc/passwd
local cmd = Awk.eval("{print $1}", "/etc/passwd", {
  field_sep = ":",
})
```

## With variables (`v`) and assignments

```lua
local Awk = require("app.awk").Awk

-- Equivalent to:
--   awk -v a=x -v b=2 '{print a, b, $1}' y=t z=9 /etc/passwd
local cmd = Awk.eval("{print a, b, $1}", "/etc/passwd", {
  vars = { a = "x", b = 2 },
  assigns = { y = "t", z = 9 },
})
```

Notes:

- `vars` (`-v`) are applied before the program.
- `assigns` (`name=value`) are appended **after** the program (and before inputs).
- For deterministic `argv`, map-form `vars`/`assigns` are **sorted by key**.

## Multiple programs (`-e`)

```lua
local Awk = require("app.awk").Awk

-- Equivalent to: awk -e 'BEGIN{a=1}' -e '{print a}' input.txt
local cmd = Awk.source({ "BEGIN{a=1}", "{print a}" }, "input.txt")
```

## Script files (`-f`)

```lua
local Awk = require("app.awk").Awk

-- Equivalent to: awk -f a.awk -f b.awk input.txt
local cmd = Awk.file({ "a.awk", "b.awk" }, "input.txt")
```

## Selected options

```lua
local Awk = require("app.awk").Awk

local cmd = Awk.eval("{print $1}", "input.txt", {
  posix = true,               -- --posix
  lint = true,                -- --lint (gawk)
  interval = true,            -- --interval (gawk)
  bignum = true,              -- --bignum (gawk)
  includes = { "inc.awk" },   -- -i inc.awk (gawk)
  debug = true,               -- --debug
  profile = "prof.out",       -- --profile=prof.out
  pretty_print = true,        -- --pretty-print
  dump_variables = "vars.out",-- --dump-variables=vars.out
  extra = { "--" },           -- any extra args before program
})
```

All functions return a `ward.process.cmd(...)` object.
