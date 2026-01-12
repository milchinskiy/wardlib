---@diagnostic disable: undefined-doc-name

-- traceroute wrapper module
--
-- Thin wrappers around `traceroute` that construct CLI invocations and return
-- `ward.process.cmd(...)` objects.
--
-- This module intentionally does not parse output; consumers can decide how to
-- execute returned commands and interpret results.

local _cmd = require("ward.process")
local validate = require("util.validate")
local ensure = require("tools.ensure")
local args_util = require("util.args")

---@class TracerouteOpts
---@field inet4 boolean? `-4`
---@field inet6 boolean? `-6`
---@field numeric boolean? `-n`
---@field as_lookup boolean? `-A` (AS number lookups)
---@field icmp boolean? `-I` (ICMP ECHO)
---@field tcp boolean? `-T` (TCP SYN)
---@field udp boolean? `-U` (UDP)
---@field method string? `-M <method>` (implementation-specific)
---@field interface string? `-i <ifname>`
---@field source string? `-s <addr>`
---@field first_ttl number? `-f <n>`
---@field max_ttl number? `-m <n>`
---@field queries number? `-q <n>`
---@field wait number? `-w <sec>` (wait for response)
---@field pause number? `-z <sec>` (pause between probes)
---@field port number? `-p <port>`
---@field do_not_fragment boolean? `-F`
---@field packetlen number? Final packet length argument (implementation-specific)
---@field extra string[]? Extra args appended after modeled options

---@class Traceroute
---@field bin string Executable name or path to `traceroute`
---@field trace fun(host: string, opts: TracerouteOpts|nil): ward.Cmd
local Traceroute = {
	bin = "traceroute",
}

---@param args string[]
---@param opts TracerouteOpts|nil
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

	if opts.numeric then
		args[#args + 1] = "-n"
	end
	if opts.as_lookup then
		args[#args + 1] = "-A"
	end

	if opts.icmp and (opts.tcp or opts.udp) then
		error("icmp is mutually exclusive with tcp/udp")
	end
	if opts.tcp and opts.udp then
		error("tcp and udp are mutually exclusive")
	end
	if opts.icmp then
		args[#args + 1] = "-I"
	end
	if opts.tcp then
		args[#args + 1] = "-T"
	end
	if opts.udp then
		args[#args + 1] = "-U"
	end
	if opts.method ~= nil then
		validate.not_flag(opts.method, "method")
		args[#args + 1] = "-M"
		args[#args + 1] = tostring(opts.method)
	end

	if opts.interface ~= nil then
		validate.non_empty_string(opts.interface, "interface")
		args[#args + 1] = "-i"
		args[#args + 1] = tostring(opts.interface)
	end
	if opts.source ~= nil then
		validate.non_empty_string(opts.source, "source")
		args[#args + 1] = "-s"
		args[#args + 1] = tostring(opts.source)
	end

	if opts.first_ttl ~= nil then
		validate.number_min(opts.first_ttl, "first_ttl", 1)
		args[#args + 1] = "-f"
		args[#args + 1] = tostring(opts.first_ttl)
	end
	if opts.max_ttl ~= nil then
		validate.number_min(opts.max_ttl, "max_ttl", 1)
		args[#args + 1] = "-m"
		args[#args + 1] = tostring(opts.max_ttl)
	end
	if opts.queries ~= nil then
		validate.number_min(opts.queries, "queries", 1)
		args[#args + 1] = "-q"
		args[#args + 1] = tostring(opts.queries)
	end
	if opts.wait ~= nil then
		validate.number_non_negative(opts.wait, "wait")
		args[#args + 1] = "-w"
		args[#args + 1] = tostring(opts.wait)
	end
	if opts.pause ~= nil then
		validate.number_non_negative(opts.pause, "pause")
		args[#args + 1] = "-z"
		args[#args + 1] = tostring(opts.pause)
	end
	if opts.port ~= nil then
		validate.number_min(opts.port, "port", 1)
		args[#args + 1] = "-p"
		args[#args + 1] = tostring(opts.port)
	end
	if opts.do_not_fragment then
		args[#args + 1] = "-F"
	end

	args_util.append_extra(args, opts.extra)
end

---Construct a traceroute command.
---@param host string
---@param opts TracerouteOpts|nil
---@return ward.Cmd
function Traceroute.trace(host, opts)
	ensure.bin(Traceroute.bin, { label = "traceroute binary" })
	validate.non_empty_string(host, "host")

	local args = { Traceroute.bin }
	apply_opts(args, opts)
	args[#args + 1] = host
	if opts ~= nil and opts.packetlen ~= nil then
		validate.number_min(opts.packetlen, "packetlen", 1)
		args[#args + 1] = tostring(opts.packetlen)
	end
	return _cmd.cmd(table.unpack(args))
end

return {
	Traceroute = Traceroute,
}
