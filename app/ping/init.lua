---@diagnostic disable: undefined-doc-name

-- ping wrapper module (iputils)
--
-- Thin wrappers around `ping` that construct CLI invocations and return
-- `ward.process.cmd(...)` objects.
--
-- This module intentionally does not parse output; consumers can decide how to
-- execute returned commands and interpret results.

local _cmd = require("ward.process")
local validate = require("util.validate")
local ensure = require("tools.ensure")
local args_util = require("util.args")

---@class PingOpts
---@field inet4 boolean? `-4`
---@field inet6 boolean? `-6`
---@field count number? `-c <n>`
---@field interval number? `-i <sec>`
---@field timeout number? `-W <sec>` (per-packet timeout)
---@field deadline number? `-w <sec>` (overall deadline)
---@field size number? `-s <bytes>`
---@field ttl number? `-t <ttl>`
---@field tos number? `-Q <tos>` (TOS/DSCP)
---@field mark number? `-m <mark>` (fwmark) NOTE: availability depends on ping implementation.
---@field interface string? `-I <ifname|addr>`
---@field source string? `-I <addr>` (alias for interface; kept for convenience)
---@field preload number? `-l <n>`
---@field flood boolean? `-f`
---@field adaptive boolean? `-A`
---@field quiet boolean? `-q`
---@field verbose boolean? `-v`
---@field audible boolean? `-a`
---@field numeric boolean? `-n`
---@field timestamp boolean? `-D`
---@field record_route boolean? `-R`
---@field pmtudisc string? `-M <do|dont|want>`
---@field pattern string? `-p <pattern>` (hex pattern)
---@field extra string[]? Extra args appended after modeled options

---@class Ping
---@field bin string Executable name or path to `ping`
---@field ping fun(dest: string, opts: PingOpts|nil): ward.Cmd
---@field once fun(dest: string, opts: PingOpts|nil): ward.Cmd
---@field flood fun(dest: string, opts: PingOpts|nil): ward.Cmd
local Ping = {
	bin = "ping",
}

---@param args string[]
---@param opts PingOpts|nil
local function apply_opts(args, opts)
	opts = opts or {}

	if opts.inet4 and opts.inet6 then
		error("inet4 and inet6 are mutually exclusive")
	end
	if opts.inet4 then
		args[#args + 1] = "-4"
	end
	if opts.inet6 then
		args[#args + 1] = "-6"
	end

	if opts.count ~= nil then
		validate.number_min(opts.count, "count", 1)
		args[#args + 1] = "-c"
		args[#args + 1] = tostring(opts.count)
	end
	if opts.interval ~= nil then
		validate.number_non_negative(opts.interval, "interval")
		args[#args + 1] = "-i"
		args[#args + 1] = tostring(opts.interval)
	end
	if opts.timeout ~= nil then
		validate.number_non_negative(opts.timeout, "timeout")
		args[#args + 1] = "-W"
		args[#args + 1] = tostring(opts.timeout)
	end
	if opts.deadline ~= nil then
		validate.number_non_negative(opts.deadline, "deadline")
		args[#args + 1] = "-w"
		args[#args + 1] = tostring(opts.deadline)
	end

	if opts.size ~= nil then
		validate.number_non_negative(opts.size, "size")
		args[#args + 1] = "-s"
		args[#args + 1] = tostring(opts.size)
	end
	if opts.ttl ~= nil then
		validate.number_min(opts.ttl, "ttl", 0)
		args[#args + 1] = "-t"
		args[#args + 1] = tostring(opts.ttl)
	end
	if opts.tos ~= nil then
		validate.number_min(opts.tos, "tos", 0)
		args[#args + 1] = "-Q"
		args[#args + 1] = tostring(opts.tos)
	end
	if opts.mark ~= nil then
		validate.number_min(opts.mark, "mark", 0)
		args[#args + 1] = "-m"
		args[#args + 1] = tostring(opts.mark)
	end

	local iface = opts.interface
	if iface == nil then
		iface = opts.source
	end
	if iface ~= nil then
		validate.non_empty_string(iface, "interface")
		args[#args + 1] = "-I"
		args[#args + 1] = tostring(iface)
	end

	if opts.preload ~= nil then
		validate.number_min(opts.preload, "preload", 1)
		args[#args + 1] = "-l"
		args[#args + 1] = tostring(opts.preload)
	end

	if opts.flood then
		args[#args + 1] = "-f"
	end
	if opts.adaptive then
		args[#args + 1] = "-A"
	end
	if opts.quiet then
		args[#args + 1] = "-q"
	end
	if opts.verbose then
		args[#args + 1] = "-v"
	end
	if opts.audible then
		args[#args + 1] = "-a"
	end
	if opts.numeric then
		args[#args + 1] = "-n"
	end
	if opts.timestamp then
		args[#args + 1] = "-D"
	end
	if opts.record_route then
		args[#args + 1] = "-R"
	end
	if opts.pmtudisc ~= nil then
		validate.not_flag(opts.pmtudisc, "pmtudisc")
		args[#args + 1] = "-M"
		args[#args + 1] = tostring(opts.pmtudisc)
	end
	if opts.pattern ~= nil then
		validate.non_empty_string(opts.pattern, "pattern")
		args[#args + 1] = "-p"
		args[#args + 1] = tostring(opts.pattern)
	end

	args_util.append_extra(args, opts.extra)
end

---Construct a ping command.
---@param dest string
---@param opts PingOpts|nil
---@return ward.Cmd
function Ping.ping(dest, opts)
	ensure.bin(Ping.bin, { label = "ping binary" })
	validate.non_empty_string(dest, "dest")

	local args = { Ping.bin }
	apply_opts(args, opts)
	args[#args + 1] = dest
	return _cmd.cmd(table.unpack(args))
end

---Convenience: ping once (`-c 1`).
---@param dest string
---@param opts PingOpts|nil
---@return ward.Cmd
function Ping.once(dest, opts)
	local o = args_util.clone_opts(opts)
	o.count = 1
	return Ping.ping(dest, o)
end

---Convenience: flood ping (`-f`).
---@param dest string
---@param opts PingOpts|nil
---@return ward.Cmd
function Ping.flood(dest, opts)
	local o = args_util.clone_opts(opts)
	o.flood = true
	return Ping.ping(dest, o)
end

return {
	Ping = Ping,
}
