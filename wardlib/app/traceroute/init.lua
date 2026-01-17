---@diagnostic disable: undefined-doc-name

-- traceroute wrapper module
--
-- Thin wrappers around `traceroute` that construct CLI invocations and return
-- `ward.process.cmd(...)` objects.
--
-- This module intentionally does not parse output; consumers can decide how to
-- execute returned commands and interpret results.

local _cmd = require("ward.process")
local args_util = require("wardlib.util.args")
local ensure = require("wardlib.tools.ensure")
local validate = require("wardlib.util.validate")

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

	if opts.inet4 and opts.inet6 then error("inet4 and inet6 are mutually exclusive") end

	if opts.icmp and (opts.tcp or opts.udp) then error("icmp is mutually exclusive with tcp/udp") end
	if opts.tcp and opts.udp then error("tcp and udp are mutually exclusive") end

	args_util
		.parser(args, opts)
		:flag("inet4", "-4")
		:flag("inet6", "-6")
		:flag("numeric", "-n")
		:flag("as_lookup", "-A")
		:flag("icmp", "-I")
		:flag("tcp", "-T")
		:flag("udp", "-U")
		:value("method", "-M", { validate = validate.not_flag })
		:value_string("interface", "-i")
		:value_string("source", "-s")
		:value_number("first_ttl", "-f", { min = 1 })
		:value_number("max_ttl", "-m", { min = 1 })
		:value_number("queries", "-q", { min = 1 })
		:value_number("wait", "-w", { non_negative = true })
		:value_number("pause", "-z", { non_negative = true })
		:value_number("port", "-p", { min = 1 })
		:flag("do_not_fragment", "-F")
		:extra()
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
