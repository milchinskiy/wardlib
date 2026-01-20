# ss

`ss` (socket statistics) is part of **iproute2** and is commonly used to
inspect TCP/UDP/UNIX sockets.

> This module constructs `ward.process.cmd(...)` invocations; it does not parse output.
> consumers can use `wardlib.tools.out` (or their own parsing) on the `:output()`
> result.

## Import

```lua
local Ss = require("wardlib.app.ss").Ss
```

## Privilege model

Many `ss` queries work unprivileged, but showing process info (`-p`) may require
additional permissions depending on your system. If you need elevation, scope
it explicitly using `wardlib.tools.with` middleware.

## API

### `Ss.bin`

Executable name or path (default: `"ss"`).

### `Ss.show(filter, opts)`

Builds: `ss <opts...> [filter...]`

- `filter`: `string|string[]|nil`
  - If `string`, appended as a single argv element.
  - If `string[]`, each element is appended as a single token
  (useful for complex filters).

### `Ss.summary(opts)`

Builds: `ss <opts...> -s`

### `Ss.listen(filter, opts)`

Builds: `ss <opts...> -l [filter...]`

### `Ss.all_sockets(filter, opts)`

Builds: `ss <opts...> -a [filter...]`

## Options

### `SsOpts`

Address family:

- `inet4: boolean?` → `-4`
- `inet6: boolean?` → `-6` (mutually exclusive with `inet4`)
- `family: string?` → `-f <family>` (e.g. `"inet"`, `"inet6"`, `"unix"`, `"link"`)

Socket types:

- `tcp: boolean?` → `-t`
- `udp: boolean?` → `-u`
- `raw: boolean?` → `-w`
- `unix: boolean?` → `-x`

Selection:

- `all: boolean?` → `-a`
- `listening: boolean?` → `-l`

Output formatting/details:

- `numeric: boolean?` → `-n`
- `resolve: boolean?` → `-r`
- `no_header: boolean?` → `-H`
- `extended: boolean?` → `-e`
- `info: boolean?` → `-i`
- `memory: boolean?` → `-m`
- `timers: boolean?` → `-o`
- `summary: boolean?` → `-s`

Process / packet (`-p`):

- `process: boolean?` → `-p` (show process using socket)
- `packet: boolean?` → `-p` (packet sockets; mutually exclusive with `process`)

SELinux context:

- `context: string?` → `-Z <context>`
- `show_context: boolean?` → `-Z`

Escape hatch:

- `extra: string[]?` → additional argv appended after modeled options

## Examples

### Show listening SSH sockets with process info

```lua
local Ss = require("wardlib.app.ss").Ss

-- ss -t -l -n -p state listening dport = :ssh
local cmd = Ss.show({ "state", "listening", "dport", "=", ":ssh" }, {
  tcp = true,
  listening = true,
  numeric = true,
  process = true,
})

cmd:run()
```

### Summary

```lua
local Ss = require("wardlib.app.ss").Ss
local out = require("wardlib.tools.out")

local txt = out.cmd(Ss.summary({ numeric = true }))
  :label("ss -s")
  :text()

-- txt contains the full summary table
```
