# rm

`rm` removes directory entries.

> This module constructs `ward.process.cmd(...)` invocations; it does not parse output.
> consumers can use `wardlib.tools.out` (or their own parsing) on the `:output()`
> result.

## Import

```lua
local Rm = require("wardlib.app.rm").Rm
```

## API

### `Rm.bin`

Executable name or path (default: `"rm"`).

### `Rm.remove(paths, opts)`

Builds: `rm <opts...> -- <paths...>`

`paths` accepts `string|string[]`.

### `Rm.raw(argv, opts)`

Builds: `rm <modeled-opts...> <argv...>`

Use this when you need `rm` flags not modeled in `RmOpts`.

## Options (`RmOpts`)

- `force: boolean?` → `-f` (mutually exclusive with `interactive`)
- `interactive: boolean?` → `-i` (mutually exclusive with `force`)
- `recursive: boolean?` → `-r` / `-R`
- `dir: boolean?` → `-d` (remove empty directories)
- `verbose: boolean?` → `-v` (GNU)
- `extra: string[]?` → extra argv appended after modeled options

## Examples

### Remove multiple paths

```lua
local Rm = require("wardlib.app.rm").Rm

-- rm -f -r -- build dist
Rm.remove({ "build", "dist" }, { force = true, recursive = true }):run()
```

### Run with elevation (when required)

Some removals require privileges (e.g. deleting root-owned files). Prefer explicit,
scoped elevation:

```lua
local Rm = require("wardlib.app.rm").Rm
local w = require("wardlib.tools.with")

w.with(w.middleware.sudo(), function()
  Rm.remove("/var/tmp/some-root-owned-file", { force = true }):run()
end)
```
