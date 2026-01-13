---@diagnostic disable: undefined-doc-name

-- ping wrapper module (iputils)
--
-- Thin wrappers around `ping` that construct CLI invocations and return
-- `ward.process.cmd(...)` objects.
--
-- This module intentionally does not parse output; consumers can decide how to
-- execute returned commands and interpret results.

local _cmd = require("ward.process")
local validate = require("wardlib.util.validate")
local ensure = require("wardlib.tools.ensure")
local args_util = require("wardlib.util.args")

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

	local p = args_util.parser(args, opts)
	p:flag("inet4", "-4")
		:flag("inet6", "-6")
		:value_number("count", "-c", { min = 1 })
		:value_number("interval", "-i", { non_negative = true })
		:value_number("timeout", "-W", { non_negative = true })
		:value_number("deadline", "-w", { non_negative = true })
		:value_number("size", "-s", { non_negative = true })
		:value_number("ttl", "-t", { min = 0 })
		:value_number("tos", "-Q", { min = 0 })
		:value_number("mark", "-m", { min = 0 })

	local iface = opts.interface
	if iface == nil then
		iface = opts.source
	end
	if iface ~= nil then
		validate.non_empty_string(iface, "interface")
		args[#args + 1] = "-I"
		args[#args + 1] = tostring(iface)
	end

	p:value_number("preload", "-l", { min = 1 })
	p:flag("flood", "-f")
		:flag("adaptive", "-A")
		:flag("quiet", "-q")
		:flag("verbose", "-v")
		:flag("audible", "-a")
		:flag("numeric", "-n")
		:flag("timestamp", "-D")
		:flag("record_route", "-R")
	p:value("pmtudisc", "-M", { validate = validate.not_flag })
	p:value_string("pattern", "-p")
	p:extra()
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
