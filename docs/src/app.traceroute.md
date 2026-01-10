# traceroute

`traceroute` discovers the network path to a destination by sending probes
with increasing TTL/hop-limit.

> The wrapper constructs a `ward.process.cmd(...)` invocation; it does not
> parse output.

## Import

```lua
local Traceroute = require("app.traceroute").Traceroute
```

## API

### `Traceroute.trace(host, opts)`

Builds: `traceroute <opts...> <host> [packetlen]`

If `opts.packetlen` is provided, it is appended after `<host>`.

## Options (`TracerouteOpts`)

Common fields:

- Address family: `inet4 (-4)`, `inet6 (-6)`
- Output: `numeric (-n)`, `as_lookup (-A)`
- Probe type: `icmp (-I)`, `tcp (-T)`, `udp (-U)`
- Method: `method (-M <method>)` (implementation-specific)
- Interface/source: `interface (-i)`, `source (-s)`
- TTL: `first_ttl (-f)`, `max_ttl (-m)`
- Probing: `queries (-q)`, `wait (-w)`, `pause (-z)`
- Ports/MTU: `port (-p)`, `do_not_fragment (-F)`
- Packet length: `packetlen` (final positional)
- Extra: `extra` (argv appended at the end)

## Examples

```lua
local Traceroute = require("app.traceroute").Traceroute

-- traceroute -n -I -m 16 -q 1 -w 2 example.com
local icmp = Traceroute.trace("example.com", {
  numeric = true,
  icmp = true,
  max_ttl = 16,
  queries = 1,
  wait = 2,
})

-- traceroute -4 -T -p 443 1.1.1.1 60
local tcp = Traceroute.trace("1.1.1.1", {
  inet4 = true,
  tcp = true,
  port = 443,
  packetlen = 60,
})
```
