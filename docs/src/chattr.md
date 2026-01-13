# chattr

`chattr` changes file attributes on Linux filesystems.

> This wrapper constructs a `ward.process.cmd(...)` invocation; it does not
> parse output.

## Import

```lua
local Chattr = require("wardlib.app.chattr").Chattr
```

## API

### `Chattr.set(paths, mode, opts)`

Builds: `chattr <opts...> -- <mode> <paths...>`

`mode` is the attribute mode string (examples: `+i`, `-i`, `=ai`).

### `Chattr.raw(argv, opts)`

Builds: `chattr <opts...> <argv...>`

## Options (`ChattrOpts`)

Modeled fields:

- `recursive (-R)`
- `verbose (-V)`
- `force (-f)`
- `version (-v <version>)`
- Escape hatch: `extra`

## Examples

```lua
local Chattr = require("wardlib.app.chattr").Chattr

-- chattr -R -- +i important.txt
local cmd1 = Chattr.set("important.txt", "+i", { recursive = true })
```
