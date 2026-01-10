# ss

`ss` (socket statistics) is part of **iproute2** and is commonly used to
inspect TCP/UDP/UNIX sockets.

> The wrapper constructs a `ward.process.cmd(...)` invocation; it does not
> parse output.

## Import

```lua
local Ss = require("app.ss").Ss
```

## API

### `Ss.show(filter, opts)`

Builds: `ss <opts...> [filter...]`

- `filter`: `string|string[]|nil`
  - If `string`, it is appended as a single argv element.
  - If `string[]`, each element is appended as one token. Use this for complex filters.

### `Ss.summary(opts)`

Builds: `ss <opts...> -s`

### `Ss.listen(filter, opts)`

Builds: `ss <opts...> -l [filter...]`

### `Ss.all_sockets(filter, opts)`

Builds: `ss <opts...> -a [filter...]`

## Options (`SsOpts`)

Common fields:

- Socket types: `tcp (-t)`, `udp (-u)`, `raw (-w)`, `unix (-x)`
- Selection: `all (-a)`, `listening (-l)`
- Formatting/detail: `numeric (-n)`, `resolve (-r)`, `no_header (-H)`,
`extended (-e)`, `info (-i)`, `memory (-m)`, `timers (-o)`
- Summary: `summary (-s)`
- Address family: `inet4 (-4)`, `inet6 (-6)`, `family (-f <family>)`
- Process: `process (-p)`
- Extra: `extra` (argv appended at the end)

Notes:

- Some `ss` builds overload `-p` for different meanings. In this wrapper,
`process = true` emits `-p` (most common). If you explicitly set
`packet = true`, it will also emit `-p` by request.

## Examples

```lua
local Ss = require("app.ss").Ss

-- ss -t -l -n -p state listening dport = :ssh
local cmd = Ss.show({ "state", "listening", "dport", "=", ":ssh" }, {
  tcp = true,
  listening = true,
  numeric = true,
  process = true,
})

-- ss -n -s
local summary = Ss.summary({ numeric = true })
```
