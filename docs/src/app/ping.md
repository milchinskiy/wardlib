# ping

`ping` (commonly from **iputils**) sends ICMP ECHO requests to test
reachability and latency.

> This module constructs `ward.process.cmd(...)` invocations; it does not parse output.
> consumers can use `wardlib.tools.out` (or their own parsing) on the `:output()`
> result.

## Import

```lua
local Ping = require("wardlib.app.ping").Ping
```

## Privilege model

On Linux, ICMP raw sockets typically require **CAP_NET_RAW**. Depending on your
system, `ping` may be:

- setuid root (traditional),
- file-capability enabled (`cap_net_raw+ep`), or
- restricted (requiring `sudo`).

If your environment requires elevation, prefer scoping it explicitly:

```lua
local w = require("wardlib.tools.with")
local Ping = require("wardlib.app.ping").Ping

w.with(w.middleware.sudo(), function()
  Ping.once("1.1.1.1"):run()
end)
```

## API

### `Ping.bin`

Executable name or path (default: `"ping"`).

### `Ping.ping(dest, opts)`

Builds: `ping <opts...> <dest>`

### `Ping.once(dest, opts)`

Builds: `ping <opts...> -c 1 <dest>`

### `Ping.flood(dest, opts)`

Builds: `ping <opts...> -f <dest>`

## Options

### `PingOpts`

- `inet4: boolean?` → `-4`
- `inet6: boolean?` → `-6` (mutually exclusive with `inet4`)
- `count: number?` → `-c <n>`
- `interval: number?` → `-i <sec>`
- `timeout: number?` → `-W <sec>` (per-packet timeout)
- `deadline: number?` → `-w <sec>` (overall deadline)
- `size: number?` → `-s <bytes>`
- `ttl: number?` → `-t <ttl>`
- `tos: number?` → `-Q <tos>` (TOS/DSCP)
- `mark: number?` → `-m <mark>` (fwmark; availability depends on ping implementation)
- `interface: string?` → `-I <ifname|addr>`
- `source: string?` → alias for `interface` (same `-I` flag)
- `preload: number?` → `-l <n>`
- `flood: boolean?` → `-f`
- `adaptive: boolean?` → `-A`
- `quiet: boolean?` → `-q`
- `verbose: boolean?` → `-v`
- `audible: boolean?` → `-a`
- `numeric: boolean?` → `-n`
- `timestamp: boolean?` → `-D`
- `record_route: boolean?` → `-R`
- `pmtudisc: string?` → `-M <do|dont|want>`
- `pattern: string?` → `-p <pattern>` (hex pattern)
- `extra: string[]?` → appended after modeled options

## Examples

### Build a command

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

cmd:run()
```

### Parse summary output

```lua
local Ping = require("wardlib.app.ping").Ping
local out = require("wardlib.tools.out")

local res = Ping.once("example.com", { numeric = true }):output()

-- You choose what to parse; this gets the last line (summary) reliably.
local summary = out.res(res)
  :label("ping")
  :lines()

local last = summary[#summary]
-- e.g. "1 packets transmitted, 1 received, 0% packet loss, time 0ms"
```
