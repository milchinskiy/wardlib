# traceroute

`traceroute` discovers the network path to a destination by sending probes
with increasing TTL/hop-limit.

> This module constructs `ward.process.cmd(...)` invocations; it does not parse output.
> consumers can use `wardlib.tools.out` (or their own parsing) on the `:output()`
> result.

Notes:

- Address family flags `-4` and `-6` are mutually exclusive.
- Probe type flags are mutually exclusive: `-I` (ICMP), `-T` (TCP), `-U` (UDP).
- Use `extra` to access unmodeled options; traceroute implementations vary
across distributions.

## Import

```lua
local Traceroute = require("wardlib.app.traceroute").Traceroute
```

## API

### `Traceroute.trace(host, opts)`

Builds: `traceroute <opts...> <host> [packetlen]`

If `opts.packetlen` is provided, it is appended after `<host>`.

## Options (`TracerouteOpts`)

- `inet4: boolean?` — `-4`
- `inet6: boolean?` — `-6`
- `numeric: boolean?` — `-n`
- `as_lookup: boolean?` — `-A` (AS number lookups)

Probe type (mutually exclusive):

- `icmp: boolean?` — `-I` (ICMP ECHO)
- `tcp: boolean?` — `-T` (TCP SYN)
- `udp: boolean?` — `-U` (UDP)

Other controls:

- `method: string?` — `-M <method>` (implementation-specific)
- `interface: string?` — `-i <ifname>`
- `source: string?` — `-s <addr>`
- `first_ttl: number?` — `-f <n>`
- `max_ttl: number?` — `-m <n>`
- `queries: number?` — `-q <n>`
- `wait: number?` — `-w <sec>` (wait for response)
- `pause: number?` — `-z <sec>` (pause between probes)
- `port: number?` — `-p <port>`
- `do_not_fragment: boolean?` — `-F`

Positional:

- `packetlen: number?` — final packet length argument

Escape hatch:

- `extra: string[]?` — extra argv appended after modeled options

## Examples

```lua
local Traceroute = require("wardlib.app.traceroute").Traceroute

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

-- traceroute -6 -n -U ipv6.google.com
local ipv6 = Traceroute.trace("ipv6.google.com", {
  inet6 = true,
  numeric = true,
  udp = true,
})
