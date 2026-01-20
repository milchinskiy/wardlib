# app.ip

`app.ip` is a thin, command-construction wrapper around the **iproute2** `ip`
binary. It returns `ward.process.cmd(...)` objects so you can execute them
using your preferred `ward.process` execution stratgy.

> This module constructs `ward.process.cmd(...)` invocations; it does not parse output.
> consumers can use `wardlib.tools.out` (or their own parsing) on the `:output()`
> result.

## Privilege escalation

Many `ip` subcommands require elevated privileges (for example, `link set`,
`addr add/del`, `route add/del`, and most `netns` operations). Prefer
`wardlib.tools.with` so privilege escalation is explicit and scoped.

```lua
local Ip = require("wardlib.app.ip").Ip
local with = require("wardlib.tools.with")

with.with(with.middleware.sudo(), function()
  -- ip link set dev eth0 up
  Ip.link_set("eth0", { up = true }):run()
end)
```

## Parsing JSON output

The wrapper does not parse output, but `ip` can emit JSON (`-j`).
Combine it with `wardlib.tools.out` for a predictable workflow.

```lua
local Ip = require("wardlib.app.ip").Ip
local out = require("wardlib.tools.out")

local addrs = out.cmd(Ip.raw({ "addr", "show" }, { json = true }))
  :label("ip -j addr show")
  :json()

-- `addrs` is an array of interfaces. Each entry contains `ifname` and `addr_info`.
-- You can filter it in Lua to find, for example, all IPv4 addresses.
```

## Global options: `IpOpts`

These options are accepted anywhere an `opts: IpOpts|nil` argument is present.

### Address-family selection

- `inet4: boolean?`
  - Adds `-4` (IPv4 only).
  - **Mutually exclusive** with `inet6`.
- `inet6: boolean?`
  - Adds `-6` (IPv6 only).
  - **Mutually exclusive** with `inet4`.
- `family: string?`
  - Adds `-f <family>`.
  - Typical values: `"inet"`, `"inet6"`, `"link"`, `"bridge"`, `"mpls"`.

### Namespace and batch execution

- `netns: string?`
  - Adds `-n <netns>`.
  - Executes the `ip` command in the context of the specified network namespace.
- `batch: string?`
  - Adds `-b <file>`.
  - Executes commands from a batch file.

### Output formatting

- `json: boolean?`
  - Adds `-j`.
  - Requests JSON output.
- `pretty: boolean?`
  - Adds `-p`.
  - Pretty-prints JSON output (typically meaningful only with `json = true`).
- `oneline: boolean?`
  - Adds `-o`.
  - One-line output formatting.
- `brief: boolean?`
  - Adds `-br`.
  - Brief output.
- `details: boolean?`
  - Adds `-d`.
  - Show details.
- `human: boolean?`
  - Adds `-h`.
  - Human-readable output.
- `resolve: boolean?`
  - Adds `-r`.
  - Resolve names (where applicable).
- `color: boolean|string?`
  - If `true`, adds `-c`.
  - If string, adds `-c <mode>`.
  - Common modes: `"auto"`, `"always"`, `"never"`.

### Timestamps and statistics

- `timestamp: boolean?`
  - Adds `-t`.
- `timestamp_short: boolean?`
  - Adds `-ts`.
- `stats: boolean|number?`
  - Adds `-s`.
  - If `true`, adds `-s` once.
  - If a number `n`, adds `-s` `n` times (iproute2 uses repeated `-s` to
  increase verbosity).

### Extra arguments

- `extra: string[]?`
  - Appended after all modeled global options.
  - Use for global flags not explicitly modeled.

---

## Methods

### `Ip.raw(argv, opts)`

Build an `ip` command from an arbitrary argument vector.

**Signature**

```lua
Ip.raw(argv: string|string[], opts: IpOpts|nil) -> ward.Cmd
```

**Semantics**

- Builds: `ip <global-opts...> <argv...>`
- Use this for unmodeled `ip` objects/subcommands.

**Example**

```lua
-- ip -d link show dev eth0
local cmd = Ip.raw({ "link", "show", "dev", "eth0" }, { details = true })
```

---

## Link operations

### `Ip.link_show(dev, opts)`

Show links (interfaces).

**Signature**

```lua
Ip.link_show(dev: string|nil, opts: IpLinkShowOpts|nil) -> ward.Cmd
```

**Generated command**

- Base: `ip <global-opts...> link show ...`

**Parameters**

- `dev: string|nil`
  - If provided, adds `dev <dev>`.

**Options: `IpLinkShowOpts`**

Extends `IpOpts` and adds:

- `up: boolean?`
  - Adds selector `up`.
- `master: string?`
  - Adds `master <ifname>` selector.
- `vrf: string?`
  - Adds `vrf <name>` selector.
- `type: string?`
  - Adds `type <kind>` selector.
- `group: string|number?`
  - Adds `group <group>` selector.

**Examples**

```lua
-- ip -br link show
local cmd1 = Ip.link_show(nil, { brief = true })

-- ip link show dev eth0 up
local cmd2 = Ip.link_show("eth0", { up = true })
```

---

### `Ip.link_set(dev, opts)`

Modify link properties.

**Signature**

```lua
Ip.link_set(dev: string, opts: IpLinkSetOpts|nil) -> ward.Cmd
```

**Generated command**

- Base: `ip <global-opts...> link set dev <dev> ...`

**Options: `IpLinkSetOpts`**

Extends `IpOpts` and adds:

- `up: boolean?`
  - Adds `up`.
  - **Mutually exclusive** with `down`.
- `down: boolean?`
  - Adds `down`.
  - **Mutually exclusive** with `up`.
- `mtu: number?`
  - Adds `mtu <n>`.
- `qlen: number?`
  - Adds `txqueuelen <n>`.
- `name: string?`
  - Adds `name <newname>`.
- `alias: string?`
  - Adds `alias <text>`.
- `address: string?`
  - Adds `address <lladdr>`.
- `broadcast: string?`
  - Adds `broadcast <lladdr>`.
- `master: string?`
  - Adds `master <ifname>`.
- `nomaster: boolean?`
  - Adds `nomaster`.
- `set_netns: string?`
  - Adds `netns <name>` (moves interface to namespace).
- `extra_after: string[]?`
  - Appended after modeled `link set` arguments.

**Examples**

```lua
-- ip link set dev eth0 up mtu 1500
local cmd = Ip.link_set("eth0", { up = true, mtu = 1500 })

-- ip link set dev eth0 netns ns1
local cmd2 = Ip.link_set("eth0", { set_netns = "ns1" })
```

---

## Address operations

### `Ip.addr_show(dev, opts)`

Show interface addresses.

**Signature**

```lua
Ip.addr_show(dev: string|nil, opts: IpAddrShowOpts|nil) -> ward.Cmd
```

**Generated command**

- Base: `ip <global-opts...> addr show ...`

**Parameters**

- `dev: string|nil`
  - If provided, adds `dev <dev>`.

**Options: `IpAddrShowOpts`**

Extends `IpOpts` and adds:

- `up: boolean?`
  - Adds selector `up`.
- `scope: string?`
  - Adds `scope <scope>` selector (e.g. `"global"`, `"link"`).
- `label: string?`
  - Adds `label <pattern>` selector.
- `to: string?`
  - Adds `to <prefix>` selector.

**Examples**

```lua
-- ip -j -p addr show dev eth0
local cmd = Ip.addr_show("eth0", { json = true, pretty = true })
```

---

### `Ip.addr_add(addr, dev, opts)`

Add an address to an interface.

**Signature**

```lua
Ip.addr_add(addr: string, dev: string, opts: IpAddrChangeOpts|nil) -> ward.Cmd
```

**Generated command**

- Base: `ip <global-opts...> addr add <addr> dev <dev> ...`

**Options: `IpAddrChangeOpts`**

Extends `IpOpts` and adds:

- `label: string?`
  - Adds `label <label>`.
- `broadcast: string?`
  - Adds `broadcast <addr>`.
- `anycast: string?`
  - Adds `anycast <addr>`.
- `scope: string?`
  - Adds `scope <scope>`.
- `valid_lft: string|number?`
  - Adds `valid_lft <time>` (e.g. `"forever"`).
- `preferred_lft: string|number?`
  - Adds `preferred_lft <time>`.
- `noprefixroute: boolean?`
  - Adds `noprefixroute`.
- `extra_after: string[]?`
  - Appended after modeled addr arguments.

**Example**

```lua
-- ip addr add 192.0.2.10/24 dev eth0
local cmd = Ip.addr_add("192.0.2.10/24", "eth0")
```

---

### `Ip.addr_del(addr, dev, opts)`

Remove an address from an interface.

**Signature**

```lua
Ip.addr_del(addr: string, dev: string, opts: IpAddrChangeOpts|nil) -> ward.Cmd
```

**Generated command**

- Base: `ip <global-opts...> addr del <addr> dev <dev> ...`

Options are identical to `Ip.addr_add` (`IpAddrChangeOpts`).

---

### `Ip.addr_flush(dev, opts)`

Flush addresses (optionally scoped/selective).

**Signature**

```lua
Ip.addr_flush(dev: string|nil, opts: IpAddrFlushOpts|nil) -> ward.Cmd
```

**Generated command**

- Base: `ip <global-opts...> addr flush ...`

**Parameters**

- `dev: string|nil`
  - If provided, adds `dev <dev>`.

**Options: `IpAddrFlushOpts`**

Extends `IpOpts` and adds:

- `scope: string?`
  - Adds `scope <scope>` selector.
- `label: string?`
  - Adds `label <pattern>` selector.
- `to: string?`
  - Adds `to <prefix>` selector.
- `extra_after: string[]?`
  - Appended after modeled flush selectors.

---

## Route operations

### `Ip.route_show(opts)`

Show routes.

**Signature**

```lua
Ip.route_show(opts: IpRouteShowOpts|nil) -> ward.Cmd
```

**Generated command**

- Base: `ip <global-opts...> route show ...`

**Options: `IpRouteShowOpts`**

Extends `IpOpts` and adds:

- `table: string|number?`
  - Adds `table <id>` selector.
- `vrf: string?`
  - Adds `vrf <name>` selector.
- `dev: string?`
  - Adds `dev <ifname>` selector.
- `proto: string?`
  - Adds `proto <proto>` selector.
- `scope: string?`
  - Adds `scope <scope>` selector.
- `type: string?`
  - Adds `type <type>` selector.
- `extra_after: string[]?`
  - Appended after modeled selectors.

---

### `Ip.route_get(dst, opts)`

Query kernel route to destination.

**Signature**

```lua
Ip.route_get(dst: string, opts: IpRouteGetOpts|nil) -> ward.Cmd
```

**Generated command**

- Base: `ip <global-opts...> route get <dst> ...`

**Options: `IpRouteGetOpts`**

Extends `IpOpts` and adds:

- `from: string?`
  - Adds `from <addr>`.
- `iif: string?`
  - Adds `iif <ifname>`.
- `oif: string?`
  - Adds `oif <ifname>`.
- `vrf: string?`
  - Adds `vrf <name>`.
- `mark: string|number?`
  - Adds `mark <fwmark>`.
- `uid: string|number?`
  - Adds `uid <uid>`.
- `extra_after: string[]?`
  - Appended after modeled args.

---

### `Ip.route_add(dst, opts)`

Add a route.

**Signature**

```lua
Ip.route_add(dst: string, opts: IpRouteChangeOpts|nil) -> ward.Cmd
```

**Generated command**

- Base: `ip <global-opts...> route add <dst> ...`

---

### `Ip.route_replace(dst, opts)`

Replace (or add) a route.

**Signature**

```lua
Ip.route_replace(dst: string, opts: IpRouteChangeOpts|nil) -> ward.Cmd
```

**Generated command**

- Base: `ip <global-opts...> route replace <dst> ...`

---

### `Ip.route_del(dst, opts)`

Delete a route.

**Signature**

```lua
Ip.route_del(dst: string, opts: IpRouteChangeOpts|nil) -> ward.Cmd
```

**Generated command**

- Base: `ip <global-opts...> route del <dst> ...`

---

### Options: `IpRouteChangeOpts`

Used by `route_add`, `route_replace`, and `route_del`.

Extends `IpOpts` and adds:

- `via: string?`
  - Adds `via <addr>`.
- `dev: string?`
  - Adds `dev <ifname>`.
- `src: string?`
  - Adds `src <addr>`.
- `metric: number?`
  - Adds `metric <n>`.
- `table: string|number?`
  - Adds `table <id>`.
- `proto: string?`
  - Adds `proto <proto>`.
- `scope: string?`
  - Adds `scope <scope>`.
- `type: string?`
  - Adds `type <type>`.
- `onlink: boolean?`
  - Adds `onlink`.
- `mtu: number?`
  - Adds `mtu <n>`.
- `advmss: number?`
  - Adds `advmss <n>`.
- `initcwnd: number?`
  - Adds `initcwnd <n>`.
- `initrwnd: number?`
  - Adds `initrwnd <n>`.
- `realm: string?`
  - Adds `realm <realm>`.
- `preference: string?`
  - Adds `pref <pref>` (common for IPv6: `"low"`, `"medium"`, `"high"`).
- `extra_after: string[]?`
  - Appended after modeled route arguments.

**Example**

```lua
-- ip -4 route add default via 192.0.2.1 dev eth0 metric 100 table 100
local cmd = Ip.route_add("default", {
  inet4 = true,
  via = "192.0.2.1",
  dev = "eth0",
  metric = 100,
  table = 100,
})
```

---

## Neighbor operations

### `Ip.neigh_show(dev, opts)`

Show neighbor table entries.

**Signature**

```lua
Ip.neigh_show(dev: string|nil, opts: IpNeighShowOpts|nil) -> ward.Cmd
```

**Generated command**

- Base: `ip <global-opts...> neigh show ...`

**Options: `IpNeighShowOpts`**

Extends `IpOpts` and adds:

- `nud: string?`
  - Adds `nud <state>` selector.
- `proxy: boolean?`
  - Adds `proxy` selector.
- `router: boolean?`
  - Adds `router` selector.
- `extra_after: string[]?`
  - Appended after modeled selectors.

---

### `Ip.neigh_add(dst, lladdr, dev, opts)`

Add a neighbor entry.

**Signature**

```lua
Ip.neigh_add(dst: string, lladdr: string, dev: string, opts: IpNeighChangeOpts|nil) -> ward.Cmd
```

**Generated command**

- Base: `ip <global-opts...> neigh add <dst> dev <dev> lladdr <lladdr> ...`

---

### `Ip.neigh_del(dst, lladdr, dev, opts)`

Delete a neighbor entry.

**Signature**

```lua
Ip.neigh_del(dst: string, lladdr: string|nil, dev: string, opts: IpNeighChangeOpts|nil) -> ward.Cmd
```

**Generated command**

- Base: `ip <global-opts...> neigh del <dst> dev <dev> [lladdr <lladdr>] ...`

---

### `Ip.neigh_flush(dev, opts)`

Flush neighbor entries.

**Signature**

```lua
Ip.neigh_flush(dev: string|nil, opts: IpNeighFlushOpts|nil) -> ward.Cmd
```

**Generated command**

- Base: `ip <global-opts...> neigh flush ...`

---

### Options: `IpNeighChangeOpts`

Used by `neigh_add` and `neigh_del`.

Extends `IpOpts` and adds:

- `nud: string?`
  - Adds `nud <state>`.
- `router: boolean?`
  - Adds `router`.
- `proxy: boolean?`
  - Adds `proxy`.
- `extra_after: string[]?`
  - Appended after modeled args.

### Options: `IpNeighFlushOpts`

Extends `IpOpts` and adds:

- `nud: string?`
  - Adds `nud <state>` selector.
- `proxy: boolean?`
  - Adds `proxy` selector.
- `extra_after: string[]?`
  - Appended after modeled selectors.

---

## Rule operations

### `Ip.rule_show(opts)`

Show policy routing rules.

**Signature**

```lua
Ip.rule_show(opts: IpRuleShowOpts|nil) -> ward.Cmd
```

**Generated command**

- Base: `ip <global-opts...> rule show ...`

**Options: `IpRuleShowOpts`**

Extends `IpOpts` and adds:

- `table: string|number?`
  - Adds `table <id>` selector.
- `extra_after: string[]?`
  - Appended after modeled selectors.

---

### `Ip.rule_add(opts)`

Add a policy routing rule.

**Signature**

```lua
Ip.rule_add(opts: IpRuleChangeOpts|nil) -> ward.Cmd
```

**Generated command**

- Base: `ip <global-opts...> rule add ...`

---

### `Ip.rule_del(opts)`

Delete a policy routing rule.

**Signature**

```lua
Ip.rule_del(opts: IpRuleChangeOpts|nil) -> ward.Cmd
```

**Generated command**

- Base: `ip <global-opts...> rule del ...`

---

### Options: `IpRuleChangeOpts`

Used by `rule_add` and `rule_del`.

Extends `IpOpts` and adds:

- `priority: number?`
  - Adds `priority <n>`.
- `from: string?`
  - Adds `from <prefix>`.
- `to: string?`
  - Adds `to <prefix>`.
- `iif: string?`
  - Adds `iif <ifname>`.
- `oif: string?`
  - Adds `oif <ifname>`.
- `fwmark: string|number?`
  - Adds `fwmark <mark>`.
- `table: string|number?`
  - Adds `table <id>`.
- `lookup: string|number?`
  - Alias for `table`. If `table` is not set, `lookup` is used.
- `suppress_prefixlength: number?`
  - Adds `suppress_prefixlength <n>`.
- `uidrange: string?`
  - Adds `uidrange <start>-<end>`.
- `extra_after: string[]?`
  - Appended after modeled args.

---

## Namespace operations

### `Ip.netns_list(opts)`

List network namespaces.

**Signature**

```lua
Ip.netns_list(opts: IpOpts|nil) -> ward.Cmd
```

**Generated command**

- `ip <global-opts...> netns list`

---

### `Ip.netns_add(name, opts)`

Create a network namespace.

**Signature**

```lua
Ip.netns_add(name: string, opts: IpOpts|nil) -> ward.Cmd
```

**Generated command**

- `ip <global-opts...> netns add <name>`

---

### `Ip.netns_del(name, opts)`

Delete a network namespace.

**Signature**

```lua
Ip.netns_del(name: string, opts: IpOpts|nil) -> ward.Cmd
```

**Generated command**

- `ip <global-opts...> netns del <name>`

---

### `Ip.netns_exec(name, argv, opts)`

Execute a command inside a network namespace.

**Signature**

```lua
Ip.netns_exec(name: string, argv: string|string[], opts: IpOpts|nil) -> ward.Cmd
```

**Generated command**

- `ip <global-opts...> netns exec <name> <argv...>`

**Example**

```lua
-- ip netns exec ns1 ip addr
local cmd = Ip.netns_exec("ns1", { "ip", "addr" })
```

---

## Monitor operations

### `Ip.monitor(objects, opts)`

Monitor changes in kernel networking objects.

**Signature**

```lua
Ip.monitor(objects: string|string[]|nil, opts: IpOpts|nil) -> ward.Cmd
```

**Generated command**

- Base: `ip <global-opts...> monitor [objects...]`

**Parameters**

- `objects: string|string[]|nil`
  - If `nil`, uses `ip monitor` default set.
  - If set, each object is appended (e.g. `"link"`, `"addr"`, `"route"`).

**Example**

```lua
-- ip -o monitor link addr
local cmd = Ip.monitor({ "link", "addr" }, { oneline = true })
```
