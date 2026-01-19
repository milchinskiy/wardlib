# ping

`ping` (commonly from **iputils**) sends ICMP ECHO requests to test
reachability and latency.

> The wrapper constructs a `ward.process.cmd(...)` invocation; it does not
> parse output.

## Import

```lua
local Ping = require("wardlib.app.ping").Ping
```

## API

### `Ping.ping(dest, opts)`

Builds: `ping <opts...> <dest>`

### `Ping.once(dest, opts)`

Builds: `ping <opts...> -c 1 <dest>`

### `Ping.flood(dest, opts)`

Builds: `ping <opts...> -f <dest>`

## Options (`PingOpts`)

Common fields:

- Address family: `inet4 (-4)`, `inet6 (-6)`
- Count/interval: `count (-c)`, `interval (-i)`
- Timeouts: `timeout (-W)`, `deadline (-w)`
- Packet: `size (-s)`, `ttl (-t)`, `tos (-Q)`
- Interface/source: `interface (-I)`, `source` (alias of `interface`)
- Behavior: `preload (-l)`, `flood (-f)`, `adaptive (-A)`
- Output: `quiet (-q)`, `verbose (-v)`, `audible (-a)`, `numeric (-n)`,
`timestamp (-D)`, `record_route (-R)`
- PMTU discovery: `pmtudisc (-M do|dont|want)`
- Pattern: `pattern (-p <hex>)`
- Extra: `extra` (argv appended at the end)

Notes:

- `mark (-m)` is not available on every `ping` implementation. This wrapper
supports it as a modeled field because it is present on many Linux builds.

## Examples

```lua
local Ping = require("wardlib.app.ping").Ping

-- ping -4 -c 3 -i 0.2 -s 56 -I eth0 1.1.1.1
local cmd = Ping.ping("1.1.1.1", {
  inet4 = true,
  count = 3,
  interval = 0.2,
  size = 56,
  interface = "eth0",
})

-- ping -c 1 -n example.com
local once = Ping.once("example.com", { numeric = true })
```
