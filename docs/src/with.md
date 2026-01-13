# tools.with

This module provides helpers to temporarily install a Ward process
middleware and then automatically restore the previous middleware stack.

The most common use-case is running commands through a prefix
command (e.g. `sudo` / `doas`) without permanently affecting subsequent
commands.

## `w.with(middleware, fn, ...) -> ...`

Runs `fn(...)` while `middleware` is installed.

```lua
local process = require("ward.process")
local w = require("wardlib.tools.with")

w.with(w.middleware.sudo(), function()
  process.cmd("id"):run()
  process.cmd("ls", "-la"):run()
end)
```

## `w.with(prefix, fn, ...) -> ...`

Convenience form: builds a prefix middleware and runs `fn(...)` under it.

```lua
local w = require("wardlib.tools.with")

w.with({"sudo", "-n"}, function()
  require("ward.process").cmd("whoami"):run()
end)
```

## `w.with(prefix_or_mw, cmd) -> cmd_proxy`

Wraps a cmd-like object, returning a proxy where any method call runs under
the given prefix/middleware.

This provides a compact syntax:

```lua
local process = require("ward.process")
local w = require("wardlib.tools.with")

local ls = w.with(process.cmd("sudo"), process.cmd("ls", "-la"))
ls:run()
```

If your local Ward `cmd(...)` object doesn't expose argv via
`.argv` / `.spec.argv` / `._spec.argv`, pass an argv array instead:

```lua
local ls = w.with({"sudo", "-n"}, process.cmd("ls", "-la"))
ls:run()
```

## `w.middleware.prefix(prefix, opts)`

Creates a middleware that prefixes `spec.argv` (or another field) with `prefix`.

Options:

- `sep` (string|nil): insert a separator token between prefix and argv (often `"--"`).
- `field` (string): which spec field to mutate (default `"argv"`).

```lua
local w = require("wardlib.tools.with")

local mw = w.middleware.prefix({"sudo", "-n"}, { sep = "--" })
```

## `w.middleware.sudo(opts)` / `w.middleware.doas(opts)`

Convenience constructors.

```lua
local w = require("wardlib.tools.with")

w.with(w.middleware.sudo({ preserve_env = true }), function()
  require("ward.process").cmd("env"):run()
end)
```
