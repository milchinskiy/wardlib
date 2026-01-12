---@diagnostic disable: undefined-doc-name

-- ip wrapper module (iproute2)
--
-- Thin wrappers around `ip` that construct CLI invocations and return
-- `ward.process.cmd(...)` objects.
--
-- This module intentionally does not parse output; consumers can decide how to
-- execute returned commands and interpret results.

local _cmd = require("ward.process")
local validate = require("util.validate")
local ensure = require("tools.ensure")
local args_util = require("util.args")

---@class IpOpts
---@field inet4 boolean? `-4`
---@field inet6 boolean? `-6`
---@field family string? `-f <family>` (e.g. "inet", "inet6", "link", "bridge", "mpls")
---@field netns string? `-n <netns>` (execute in namespace context)
---@field batch string? `-b <file>` (batch mode)
---@field json boolean? `-j` / `-json`
---@field pretty boolean? `-p` (pretty JSON; typically used with `-j`)
---@field oneline boolean? `-o`
---@field brief boolean? `-br`
---@field details boolean? `-d`
---@field stats boolean|number? `-s` (true = once; number = repeat count)
---@field human boolean? `-h`
---@field resolve boolean? `-r`
---@field color boolean|string? `-c` or `-c <mode>` (mode commonly: "auto"|"always"|"never")
---@field timestamp boolean? `-t`
---@field timestamp_short boolean? `-ts`
---@field extra string[]? Extra args appended after modeled options

---@class Ip
---@field bin string Executable name or path to `ip`
---@field raw fun(argv: string|string[], opts: IpOpts|nil): ward.Cmd
---@field link_show fun(dev: string|nil, opts: table|nil): ward.Cmd
---@field link_set fun(dev: string, opts: table|nil): ward.Cmd
---@field addr_show fun(dev: string|nil, opts: table|nil): ward.Cmd
---@field addr_add fun(addr: string, dev: string, opts: table|nil): ward.Cmd
---@field addr_del fun(addr: string, dev: string, opts: table|nil): ward.Cmd
---@field addr_flush fun(dev: string|nil, opts: table|nil): ward.Cmd
---@field route_show fun(opts: table|nil): ward.Cmd
---@field route_get fun(dst: string, opts: table|nil): ward.Cmd
---@field route_add fun(dst: string, opts: table|nil): ward.Cmd
---@field route_replace fun(dst: string, opts: table|nil): ward.Cmd
---@field route_del fun(dst: string, opts: table|nil): ward.Cmd
---@field neigh_show fun(dev: string|nil, opts: table|nil): ward.Cmd
---@field neigh_add fun(dst: string, lladdr: string, dev: string, opts: table|nil): ward.Cmd
---@field neigh_del fun(dst: string, lladdr: string|nil, dev: string, opts: table|nil): ward.Cmd
---@field neigh_flush fun(dev: string|nil, opts: table|nil): ward.Cmd
---@field rule_show fun(opts: table|nil): ward.Cmd
---@field rule_add fun(opts: table|nil): ward.Cmd
---@field rule_del fun(opts: table|nil): ward.Cmd
---@field netns_list fun(opts: IpOpts|nil): ward.Cmd
---@field netns_add fun(name: string, opts: IpOpts|nil): ward.Cmd
---@field netns_del fun(name: string, opts: IpOpts|nil): ward.Cmd
---@field netns_exec fun(name: string, argv: string|string[], opts: IpOpts|nil): ward.Cmd
---@field monitor fun(objects: string|string[]|nil, opts: IpOpts|nil): ward.Cmd
local Ip = {
	bin = "ip",
}

---@param v any
---@param label string
local function non_empty_string(v, label)
	validate.non_empty_string(v, label)
	return v
end

---@param args string[]
---@param opts IpOpts|nil
local function apply_global_opts(args, opts)
	opts = opts or {}

	if opts.inet4 and opts.inet6 then
		error("inet4 and inet6 are mutually exclusive")
	end

	local function validate_color(v, label)
		if type(v) ~= "string" then
			error(label .. " must be boolean or string")
		end
		validate.not_flag(v, label)
	end

	args_util
		.parser(args, opts)
		:flag("inet4", "-4")
		:flag("inet6", "-6")
		:value_token("family", "-f", "family")
		:value_string("netns", "-n", "netns")
		:value_string("batch", "-b", "batch")
		:flag("json", "-j")
		:flag("pretty", "-p")
		:flag("oneline", "-o")
		:flag("brief", "-br")
		:flag("details", "-d")
		:flag("human", "-h")
		:flag("resolve", "-r")
		:flag("timestamp", "-t")
		:flag("timestamp_short", "-ts")
		:count("stats", "-s", { label = "stats", true_count = 1, min = 1 })
		:bool_or_value("color", "-c", { label = "color", validate = validate_color })
		:extra("extra")
end

---@param obj string
---@param cmd string
---@param tail string[]|nil
---@param opts IpOpts|nil
---@return ward.Cmd
local function build(obj, cmd, tail, opts)
	ensure.bin(Ip.bin, { label = "ip binary" })

	local args = { Ip.bin }
	apply_global_opts(args, opts)
	args[#args + 1] = obj
	args[#args + 1] = cmd
	if tail ~= nil then
		for _, v in ipairs(tail) do
			args[#args + 1] = tostring(v)
		end
	end
	return _cmd.cmd(table.unpack(args))
end

---Build an `ip` command with arbitrary argv.
---
---Example:
---  Ip.raw({"link", "show", "dev", "eth0"}, { json = true })
---
---@param argv string|string[]
---@param opts IpOpts|nil
---@return ward.Cmd
function Ip.raw(argv, opts)
	ensure.bin(Ip.bin, { label = "ip binary" })

	local args = { Ip.bin }
	apply_global_opts(args, opts)
	local argvv = args_util.normalize_string_or_array(argv, "argv")
	for _, s in ipairs(argvv) do
		args[#args + 1] = s
	end
	return _cmd.cmd(table.unpack(args))
end

-- =========================
-- link
-- =========================

---@class IpLinkShowOpts: IpOpts
---@field up boolean? Add `up` selector
---@field master string? `master <ifname>` selector
---@field vrf string? `vrf <name>` selector
---@field type string? `type <kind>` selector
---@field group string|number? `group <group>` selector

---@param dev string|nil
---@param opts IpLinkShowOpts|nil
---@return ward.Cmd
function Ip.link_show(dev, opts)
	local tail = {}
	if dev ~= nil then
		non_empty_string(dev, "dev")
		tail[#tail + 1] = "dev"
		tail[#tail + 1] = dev
	end
	if opts ~= nil then
		if opts.up then
			tail[#tail + 1] = "up"
		end
		if opts.master ~= nil then
			non_empty_string(opts.master, "master")
			tail[#tail + 1] = "master"
			tail[#tail + 1] = opts.master
		end
		if opts.vrf ~= nil then
			non_empty_string(opts.vrf, "vrf")
			tail[#tail + 1] = "vrf"
			tail[#tail + 1] = opts.vrf
		end
		if opts.type ~= nil then
			non_empty_string(opts.type, "type")
			tail[#tail + 1] = "type"
			tail[#tail + 1] = opts.type
		end
		if opts.group ~= nil then
			tail[#tail + 1] = "group"
			tail[#tail + 1] = tostring(opts.group)
		end
	end

	return build("link", "show", tail, opts)
end

---@class IpLinkSetOpts: IpOpts
---@field up boolean? `up`
---@field down boolean? `down`
---@field mtu number? `mtu <n>`
---@field qlen number? `txqueuelen <n>`
---@field name string? `name <newname>`
---@field alias string? `alias <text>`
---@field address string? `address <lladdr>`
---@field broadcast string? `broadcast <lladdr>`
---@field master string? `master <ifname>`
---@field nomaster boolean? `nomaster`
---@field set_netns string? `netns <name>` (move interface to namespace)
---@field extra_after string[]? Extra args appended after modeled *link-set* arguments

---@param dev string
---@param opts IpLinkSetOpts|nil
---@return ward.Cmd
function Ip.link_set(dev, opts)
	non_empty_string(dev, "dev")
	opts = opts or {}

	if opts.up and opts.down then
		error("up and down are mutually exclusive")
	end

	local tail = { "dev", dev }
	if opts.up then
		tail[#tail + 1] = "up"
	end
	if opts.down then
		tail[#tail + 1] = "down"
	end
	if opts.mtu ~= nil then
		validate.number_min(opts.mtu, "mtu", 0)
		tail[#tail + 1] = "mtu"
		tail[#tail + 1] = tostring(opts.mtu)
	end
	if opts.qlen ~= nil then
		validate.number_min(opts.qlen, "qlen", 0)
		tail[#tail + 1] = "txqueuelen"
		tail[#tail + 1] = tostring(opts.qlen)
	end
	if opts.name ~= nil then
		non_empty_string(opts.name, "name")
		tail[#tail + 1] = "name"
		tail[#tail + 1] = opts.name
	end
	if opts.alias ~= nil then
		non_empty_string(opts.alias, "alias")
		tail[#tail + 1] = "alias"
		tail[#tail + 1] = opts.alias
	end
	if opts.address ~= nil then
		non_empty_string(opts.address, "address")
		tail[#tail + 1] = "address"
		tail[#tail + 1] = opts.address
	end
	if opts.broadcast ~= nil then
		non_empty_string(opts.broadcast, "broadcast")
		tail[#tail + 1] = "broadcast"
		tail[#tail + 1] = opts.broadcast
	end
	if opts.master ~= nil then
		non_empty_string(opts.master, "master")
		tail[#tail + 1] = "master"
		tail[#tail + 1] = opts.master
	end
	if opts.nomaster then
		tail[#tail + 1] = "nomaster"
	end
	if opts.set_netns ~= nil then
		non_empty_string(opts.set_netns, "set_netns")
		tail[#tail + 1] = "netns"
		tail[#tail + 1] = opts.set_netns
	end

	args_util.append_extra(tail, opts.extra_after)
	return build("link", "set", tail, opts)
end

-- =========================
-- addr
-- =========================

---@class IpAddrShowOpts: IpOpts
---@field up boolean? Add `up` selector
---@field scope string? `scope <scope>` selector (e.g. "global", "link")
---@field label string? `label <pattern>` selector
---@field to string? `to <prefix>` selector

---@param dev string|nil
---@param opts IpAddrShowOpts|nil
---@return ward.Cmd
function Ip.addr_show(dev, opts)
	local tail = {}
	if dev ~= nil then
		non_empty_string(dev, "dev")
		tail[#tail + 1] = "dev"
		tail[#tail + 1] = dev
	end
	opts = opts or {}
	if opts.up then
		tail[#tail + 1] = "up"
	end
	if opts.scope ~= nil then
		non_empty_string(opts.scope, "scope")
		tail[#tail + 1] = "scope"
		tail[#tail + 1] = opts.scope
	end
	if opts.label ~= nil then
		non_empty_string(opts.label, "label")
		tail[#tail + 1] = "label"
		tail[#tail + 1] = opts.label
	end
	if opts.to ~= nil then
		non_empty_string(opts.to, "to")
		tail[#tail + 1] = "to"
		tail[#tail + 1] = opts.to
	end
	return build("addr", "show", tail, opts)
end

---@class IpAddrChangeOpts: IpOpts
---@field label string? `label <label>`
---@field broadcast string? `broadcast <addr>`
---@field anycast string? `anycast <addr>`
---@field scope string? `scope <scope>`
---@field valid_lft string|number? `valid_lft <time>` (e.g. "forever")
---@field preferred_lft string|number? `preferred_lft <time>`
---@field noprefixroute boolean? `noprefixroute`
---@field extra_after string[]? Extra args appended after modeled addr arguments

---@param action "add"|"del"
---@param addr string
---@param dev string
---@param opts IpAddrChangeOpts|nil
---@return ward.Cmd
local function addr_change(action, addr, dev, opts)
	non_empty_string(addr, "addr")
	non_empty_string(dev, "dev")
	opts = opts or {}

	local tail = { addr, "dev", dev }
	if opts.label ~= nil then
		non_empty_string(opts.label, "label")
		tail[#tail + 1] = "label"
		tail[#tail + 1] = opts.label
	end
	if opts.broadcast ~= nil then
		non_empty_string(opts.broadcast, "broadcast")
		tail[#tail + 1] = "broadcast"
		tail[#tail + 1] = opts.broadcast
	end
	if opts.anycast ~= nil then
		non_empty_string(opts.anycast, "anycast")
		tail[#tail + 1] = "anycast"
		tail[#tail + 1] = opts.anycast
	end
	if opts.scope ~= nil then
		non_empty_string(opts.scope, "scope")
		tail[#tail + 1] = "scope"
		tail[#tail + 1] = opts.scope
	end
	if opts.valid_lft ~= nil then
		tail[#tail + 1] = "valid_lft"
		tail[#tail + 1] = tostring(opts.valid_lft)
	end
	if opts.preferred_lft ~= nil then
		tail[#tail + 1] = "preferred_lft"
		tail[#tail + 1] = tostring(opts.preferred_lft)
	end
	if opts.noprefixroute then
		tail[#tail + 1] = "noprefixroute"
	end

	args_util.append_extra(tail, opts.extra_after)
	return build("addr", action, tail, opts)
end

---@param addr string
---@param dev string
---@param opts IpAddrChangeOpts|nil
---@return ward.Cmd
function Ip.addr_add(addr, dev, opts)
	return addr_change("add", addr, dev, opts)
end

---@param addr string
---@param dev string
---@param opts IpAddrChangeOpts|nil
---@return ward.Cmd
function Ip.addr_del(addr, dev, opts)
	return addr_change("del", addr, dev, opts)
end

---@class IpAddrFlushOpts: IpOpts
---@field scope string? `scope <scope>` selector
---@field label string? `label <pattern>` selector
---@field to string? `to <prefix>` selector
---@field extra_after string[]? Extra args appended after modeled flush arguments

---@param dev string|nil
---@param opts IpAddrFlushOpts|nil
---@return ward.Cmd
function Ip.addr_flush(dev, opts)
	opts = opts or {}
	local tail = {}
	if dev ~= nil then
		non_empty_string(dev, "dev")
		tail[#tail + 1] = "dev"
		tail[#tail + 1] = dev
	end
	if opts.scope ~= nil then
		non_empty_string(opts.scope, "scope")
		tail[#tail + 1] = "scope"
		tail[#tail + 1] = opts.scope
	end
	if opts.label ~= nil then
		non_empty_string(opts.label, "label")
		tail[#tail + 1] = "label"
		tail[#tail + 1] = opts.label
	end
	if opts.to ~= nil then
		non_empty_string(opts.to, "to")
		tail[#tail + 1] = "to"
		tail[#tail + 1] = opts.to
	end
	args_util.append_extra(tail, opts.extra_after)
	return build("addr", "flush", tail, opts)
end

-- =========================
-- route
-- =========================

---@class IpRouteShowOpts: IpOpts
---@field table string|number? `table <id>` selector
---@field vrf string? `vrf <name>` selector
---@field dev string? `dev <ifname>` selector
---@field proto string? `proto <proto>` selector
---@field scope string? `scope <scope>` selector
---@field type string? `type <type>` selector
---@field extra_after string[]? Extra args appended after modeled selectors

---@param opts IpRouteShowOpts|nil
---@return ward.Cmd
function Ip.route_show(opts)
	opts = opts or {}
	local tail = {}
	if opts.table ~= nil then
		tail[#tail + 1] = "table"
		tail[#tail + 1] = tostring(opts.table)
	end
	if opts.vrf ~= nil then
		non_empty_string(opts.vrf, "vrf")
		tail[#tail + 1] = "vrf"
		tail[#tail + 1] = opts.vrf
	end
	if opts.dev ~= nil then
		non_empty_string(opts.dev, "dev")
		tail[#tail + 1] = "dev"
		tail[#tail + 1] = opts.dev
	end
	if opts.proto ~= nil then
		non_empty_string(opts.proto, "proto")
		tail[#tail + 1] = "proto"
		tail[#tail + 1] = opts.proto
	end
	if opts.scope ~= nil then
		non_empty_string(opts.scope, "scope")
		tail[#tail + 1] = "scope"
		tail[#tail + 1] = opts.scope
	end
	if opts.type ~= nil then
		non_empty_string(opts.type, "type")
		tail[#tail + 1] = "type"
		tail[#tail + 1] = opts.type
	end
	args_util.append_extra(tail, opts.extra_after)
	return build("route", "show", tail, opts)
end

---@class IpRouteGetOpts: IpOpts
---@field from string? `from <addr>`
---@field iif string? `iif <ifname>`
---@field oif string? `oif <ifname>`
---@field vrf string? `vrf <name>`
---@field mark string|number? `mark <fwmark>`
---@field uid string|number? `uid <uid>`
---@field extra_after string[]? Extra args appended after modeled args

---@param dst string
---@param opts IpRouteGetOpts|nil
---@return ward.Cmd
function Ip.route_get(dst, opts)
	non_empty_string(dst, "dst")
	opts = opts or {}

	local tail = { dst }
	if opts.from ~= nil then
		non_empty_string(opts.from, "from")
		tail[#tail + 1] = "from"
		tail[#tail + 1] = opts.from
	end
	if opts.iif ~= nil then
		non_empty_string(opts.iif, "iif")
		tail[#tail + 1] = "iif"
		tail[#tail + 1] = opts.iif
	end
	if opts.oif ~= nil then
		non_empty_string(opts.oif, "oif")
		tail[#tail + 1] = "oif"
		tail[#tail + 1] = opts.oif
	end
	if opts.vrf ~= nil then
		non_empty_string(opts.vrf, "vrf")
		tail[#tail + 1] = "vrf"
		tail[#tail + 1] = opts.vrf
	end
	if opts.mark ~= nil then
		tail[#tail + 1] = "mark"
		tail[#tail + 1] = tostring(opts.mark)
	end
	if opts.uid ~= nil then
		tail[#tail + 1] = "uid"
		tail[#tail + 1] = tostring(opts.uid)
	end

	args_util.append_extra(tail, opts.extra_after)
	return build("route", "get", tail, opts)
end

---@class IpRouteChangeOpts: IpOpts
---@field via string? `via <addr>`
---@field dev string? `dev <ifname>`
---@field src string? `src <addr>`
---@field metric number? `metric <n>`
---@field table string|number? `table <id>`
---@field proto string? `proto <proto>`
---@field scope string? `scope <scope>`
---@field type string? `type <type>`
---@field onlink boolean? `onlink`
---@field mtu number? `mtu <n>`
---@field advmss number? `advmss <n>`
---@field initcwnd number? `initcwnd <n>`
---@field initrwnd number? `initrwnd <n>`
---@field realm string? `realm <realm>`
---@field preference string? `pref <pref>` (common for IPv6: "low"|"medium"|"high")
---@field extra_after string[]? Extra args appended after modeled route arguments

---@param action "add"|"replace"|"del"
---@param dst string
---@param opts IpRouteChangeOpts|nil
---@return ward.Cmd
local function route_change(action, dst, opts)
	non_empty_string(dst, "dst")
	opts = opts or {}

	local tail = { dst }
	if opts.via ~= nil then
		non_empty_string(opts.via, "via")
		tail[#tail + 1] = "via"
		tail[#tail + 1] = opts.via
	end
	if opts.dev ~= nil then
		non_empty_string(opts.dev, "dev")
		tail[#tail + 1] = "dev"
		tail[#tail + 1] = opts.dev
	end
	if opts.src ~= nil then
		non_empty_string(opts.src, "src")
		tail[#tail + 1] = "src"
		tail[#tail + 1] = opts.src
	end
	if opts.metric ~= nil then
		validate.number_min(opts.metric, "metric", 0)
		tail[#tail + 1] = "metric"
		tail[#tail + 1] = tostring(opts.metric)
	end
	if opts.table ~= nil then
		tail[#tail + 1] = "table"
		tail[#tail + 1] = tostring(opts.table)
	end
	if opts.proto ~= nil then
		non_empty_string(opts.proto, "proto")
		tail[#tail + 1] = "proto"
		tail[#tail + 1] = opts.proto
	end
	if opts.scope ~= nil then
		non_empty_string(opts.scope, "scope")
		tail[#tail + 1] = "scope"
		tail[#tail + 1] = opts.scope
	end
	if opts.type ~= nil then
		non_empty_string(opts.type, "type")
		tail[#tail + 1] = "type"
		tail[#tail + 1] = opts.type
	end
	if opts.onlink then
		tail[#tail + 1] = "onlink"
	end
	if opts.mtu ~= nil then
		validate.number_min(opts.mtu, "mtu", 0)
		tail[#tail + 1] = "mtu"
		tail[#tail + 1] = tostring(opts.mtu)
	end
	if opts.advmss ~= nil then
		validate.number_min(opts.advmss, "advmss", 0)
		tail[#tail + 1] = "advmss"
		tail[#tail + 1] = tostring(opts.advmss)
	end
	if opts.initcwnd ~= nil then
		validate.number_min(opts.initcwnd, "initcwnd", 0)
		tail[#tail + 1] = "initcwnd"
		tail[#tail + 1] = tostring(opts.initcwnd)
	end
	if opts.initrwnd ~= nil then
		validate.number_min(opts.initrwnd, "initrwnd", 0)
		tail[#tail + 1] = "initrwnd"
		tail[#tail + 1] = tostring(opts.initrwnd)
	end
	if opts.realm ~= nil then
		non_empty_string(opts.realm, "realm")
		tail[#tail + 1] = "realm"
		tail[#tail + 1] = opts.realm
	end
	if opts.preference ~= nil then
		non_empty_string(opts.preference, "preference")
		tail[#tail + 1] = "pref"
		tail[#tail + 1] = opts.preference
	end

	args_util.append_extra(tail, opts.extra_after)
	return build("route", action, tail, opts)
end

---@param dst string
---@param opts IpRouteChangeOpts|nil
---@return ward.Cmd
function Ip.route_add(dst, opts)
	return route_change("add", dst, opts)
end

---@param dst string
---@param opts IpRouteChangeOpts|nil
---@return ward.Cmd
function Ip.route_replace(dst, opts)
	return route_change("replace", dst, opts)
end

---@param dst string
---@param opts IpRouteChangeOpts|nil
---@return ward.Cmd
function Ip.route_del(dst, opts)
	return route_change("del", dst, opts)
end

-- =========================
-- neigh
-- =========================

---@class IpNeighShowOpts: IpOpts
---@field nud string? `nud <state>` selector
---@field proxy boolean? `proxy` selector
---@field router boolean? `router` selector
---@field extra_after string[]? Extra args appended after modeled selectors

---@param dev string|nil
---@param opts IpNeighShowOpts|nil
---@return ward.Cmd
function Ip.neigh_show(dev, opts)
	opts = opts or {}
	local tail = {}
	if dev ~= nil then
		non_empty_string(dev, "dev")
		tail[#tail + 1] = "dev"
		tail[#tail + 1] = dev
	end
	if opts.nud ~= nil then
		non_empty_string(opts.nud, "nud")
		tail[#tail + 1] = "nud"
		tail[#tail + 1] = opts.nud
	end
	if opts.proxy then
		tail[#tail + 1] = "proxy"
	end
	if opts.router then
		tail[#tail + 1] = "router"
	end
	args_util.append_extra(tail, opts.extra_after)
	return build("neigh", "show", tail, opts)
end

---@class IpNeighChangeOpts: IpOpts
---@field nud string? `nud <state>`
---@field router boolean? `router`
---@field proxy boolean? `proxy`
---@field extra_after string[]? Extra args appended after modeled args

---@param action "add"|"del"
---@param dst string
---@param lladdr string|nil
---@param dev string
---@param opts IpNeighChangeOpts|nil
---@return ward.Cmd
local function neigh_change(action, dst, lladdr, dev, opts)
	non_empty_string(dst, "dst")
	non_empty_string(dev, "dev")
	opts = opts or {}

	local tail = { dst, "dev", dev }
	if lladdr ~= nil then
		non_empty_string(lladdr, "lladdr")
		tail[#tail + 1] = "lladdr"
		tail[#tail + 1] = lladdr
	end
	if opts.nud ~= nil then
		non_empty_string(opts.nud, "nud")
		tail[#tail + 1] = "nud"
		tail[#tail + 1] = opts.nud
	end
	if opts.router then
		tail[#tail + 1] = "router"
	end
	if opts.proxy then
		tail[#tail + 1] = "proxy"
	end

	args_util.append_extra(tail, opts.extra_after)
	return build("neigh", action, tail, opts)
end

---@param dst string
---@param lladdr string
---@param dev string
---@param opts IpNeighChangeOpts|nil
---@return ward.Cmd
function Ip.neigh_add(dst, lladdr, dev, opts)
	return neigh_change("add", dst, lladdr, dev, opts)
end

---@param dst string
---@param lladdr string|nil
---@param dev string
---@param opts IpNeighChangeOpts|nil
---@return ward.Cmd
function Ip.neigh_del(dst, lladdr, dev, opts)
	return neigh_change("del", dst, lladdr, dev, opts)
end

---@class IpNeighFlushOpts: IpOpts
---@field nud string? `nud <state>` selector
---@field proxy boolean? `proxy` selector
---@field extra_after string[]? Extra args appended after modeled selectors

---@param dev string|nil
---@param opts IpNeighFlushOpts|nil
---@return ward.Cmd
function Ip.neigh_flush(dev, opts)
	opts = opts or {}
	local tail = {}
	if dev ~= nil then
		non_empty_string(dev, "dev")
		tail[#tail + 1] = "dev"
		tail[#tail + 1] = dev
	end
	if opts.nud ~= nil then
		non_empty_string(opts.nud, "nud")
		tail[#tail + 1] = "nud"
		tail[#tail + 1] = opts.nud
	end
	if opts.proxy then
		tail[#tail + 1] = "proxy"
	end
	args_util.append_extra(tail, opts.extra_after)
	return build("neigh", "flush", tail, opts)
end

-- =========================
-- rule
-- =========================

---@class IpRuleShowOpts: IpOpts
---@field table string|number? `table <id>` selector
---@field extra_after string[]? Extra args appended after modeled selectors

---@param opts IpRuleShowOpts|nil
---@return ward.Cmd
function Ip.rule_show(opts)
	opts = opts or {}
	local tail = {}
	if opts.table ~= nil then
		tail[#tail + 1] = "table"
		tail[#tail + 1] = tostring(opts.table)
	end
	args_util.append_extra(tail, opts.extra_after)
	return build("rule", "show", tail, opts)
end

---@class IpRuleChangeOpts: IpOpts
---@field priority number? `priority <n>`
---@field from string? `from <prefix>`
---@field to string? `to <prefix>`
---@field iif string? `iif <ifname>`
---@field oif string? `oif <ifname>`
---@field fwmark string|number? `fwmark <mark>`
---@field table string|number? `table <id>`
---@field lookup string|number? `lookup <table>` (alias for `table`, kept for user convenience)
---@field suppress_prefixlength number? `suppress_prefixlength <n>`
---@field uidrange string? `uidrange <start>-<end>`
---@field extra_after string[]? Extra args appended after modeled args

---@param action "add"|"del"
---@param opts IpRuleChangeOpts|nil
---@return ward.Cmd
local function rule_change(action, opts)
	opts = opts or {}
	local tail = {}
	if opts.priority ~= nil then
		validate.number_min(opts.priority, "priority", 0)
		tail[#tail + 1] = "priority"
		tail[#tail + 1] = tostring(opts.priority)
	end
	if opts.from ~= nil then
		non_empty_string(opts.from, "from")
		tail[#tail + 1] = "from"
		tail[#tail + 1] = opts.from
	end
	if opts.to ~= nil then
		non_empty_string(opts.to, "to")
		tail[#tail + 1] = "to"
		tail[#tail + 1] = opts.to
	end
	if opts.iif ~= nil then
		non_empty_string(opts.iif, "iif")
		tail[#tail + 1] = "iif"
		tail[#tail + 1] = opts.iif
	end
	if opts.oif ~= nil then
		non_empty_string(opts.oif, "oif")
		tail[#tail + 1] = "oif"
		tail[#tail + 1] = opts.oif
	end
	if opts.fwmark ~= nil then
		tail[#tail + 1] = "fwmark"
		tail[#tail + 1] = tostring(opts.fwmark)
	end
	local table_id = opts.table
	if table_id == nil then
		table_id = opts.lookup
	end
	if table_id ~= nil then
		tail[#tail + 1] = "table"
		tail[#tail + 1] = tostring(table_id)
	end
	if opts.suppress_prefixlength ~= nil then
		validate.number_min(opts.suppress_prefixlength, "suppress_prefixlength", 0)
		tail[#tail + 1] = "suppress_prefixlength"
		tail[#tail + 1] = tostring(opts.suppress_prefixlength)
	end
	if opts.uidrange ~= nil then
		non_empty_string(opts.uidrange, "uidrange")
		tail[#tail + 1] = "uidrange"
		tail[#tail + 1] = opts.uidrange
	end

	args_util.append_extra(tail, opts.extra_after)
	return build("rule", action, tail, opts)
end

---@param opts IpRuleChangeOpts|nil
---@return ward.Cmd
function Ip.rule_add(opts)
	return rule_change("add", opts)
end

---@param opts IpRuleChangeOpts|nil
---@return ward.Cmd
function Ip.rule_del(opts)
	return rule_change("del", opts)
end

-- =========================
-- netns
-- =========================

---@param opts IpOpts|nil
---@return ward.Cmd
function Ip.netns_list(opts)
	return build("netns", "list", nil, opts)
end

---@param name string
---@param opts IpOpts|nil
---@return ward.Cmd
function Ip.netns_add(name, opts)
	non_empty_string(name, "name")
	return build("netns", "add", { name }, opts)
end

---@param name string
---@param opts IpOpts|nil
---@return ward.Cmd
function Ip.netns_del(name, opts)
	non_empty_string(name, "name")
	return build("netns", "del", { name }, opts)
end

---@param name string
---@param argv string|string[]
---@param opts IpOpts|nil
---@return ward.Cmd
function Ip.netns_exec(name, argv, opts)
	non_empty_string(name, "name")
	ensure.bin(Ip.bin, { label = "ip binary" })

	local args = { Ip.bin }
	apply_global_opts(args, opts)
	args[#args + 1] = "netns"
	args[#args + 1] = "exec"
	args[#args + 1] = name
	local argvv = args_util.normalize_string_or_array(argv, "argv")
	for _, s in ipairs(argvv) do
		args[#args + 1] = s
	end
	return _cmd.cmd(table.unpack(args))
end

-- =========================
-- monitor
-- =========================

---@param objects string|string[]|nil Object list (e.g. "link", "addr", "route") or nil for default
---@param opts IpOpts|nil
---@return ward.Cmd
function Ip.monitor(objects, opts)
	ensure.bin(Ip.bin, { label = "ip binary" })

	local args = { Ip.bin }
	apply_global_opts(args, opts)
	args[#args + 1] = "monitor"
	if objects ~= nil then
		local objs = args_util.normalize_string_or_array(objects, "objects")
		for _, o in ipairs(objs) do
			args[#args + 1] = o
		end
	end
	return _cmd.cmd(table.unpack(args))
end

return {
	Ip = Ip,
}
