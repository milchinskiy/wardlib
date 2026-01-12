---@diagnostic disable: undefined-doc-name

-- ss wrapper module (iproute2)
--
-- Thin wrappers around `ss` that construct CLI invocations and return
-- `ward.process.cmd(...)` objects.
--
-- This module intentionally does not parse output; consumers can decide how to
-- execute returned commands and interpret results.

local _cmd = require("ward.process")
local validate = require("util.validate")
local ensure = require("tools.ensure")
local args_util = require("util.args")

---@class SsOpts
---@field tcp boolean? `-t`
---@field udp boolean? `-u`
---@field raw boolean? `-w`
---@field unix boolean? `-x`
---@field packet boolean? `-p` (packet sockets) NOTE: collides with `process`; use `packet = true` only if you know your ss supports it.
---@field process boolean? `-p` (show process using socket)
---@field all boolean? `-a` (all)
---@field listening boolean? `-l` (listening)
---@field numeric boolean? `-n` (do not resolve service names)
---@field resolve boolean? `-r` (resolve names)
---@field no_header boolean? `-H`
---@field extended boolean? `-e` (extended)
---@field info boolean? `-i` (internal TCP information)
---@field memory boolean? `-m` (memory)
---@field timers boolean? `-o` (timer information)
---@field summary boolean? `-s` (summary)
---@field inet4 boolean? `-4`
---@field inet6 boolean? `-6`
---@field family string? `-f <family>` (e.g. "inet", "inet6", "unix", "link")
---@field context string? `-Z <context>` (SELinux context)
---@field show_context boolean? `-Z` (SELinux context)
---@field extra string[]? Extra args appended after modeled options

---@class Ss
---@field bin string Executable name or path to `ss`
---@field show fun(filter: string|string[]|nil, opts: SsOpts|nil): ward.Cmd
---@field summary fun(opts: SsOpts|nil): ward.Cmd
---@field listen fun(filter: string|string[]|nil, opts: SsOpts|nil): ward.Cmd
---@field all_sockets fun(filter: string|string[]|nil, opts: SsOpts|nil): ward.Cmd
local Ss = {
	bin = "ss",
}

---@param args string[]
---@param opts SsOpts|nil
local function apply_opts(args, opts)
	opts = opts or {}

	-- Address family
	if opts.inet4 and opts.inet6 then
		error("inet4 and inet6 are mutually exclusive")
	end

	-- Process / packet sockets
	if opts.process and opts.packet then
		error("process and packet are mutually exclusive")
	end

	local p = args_util.parser(args, opts)
	-- Address family
	p:flag("inet4", "-4"):flag("inet6", "-6"):value_token("family", "-f", "family")

	-- Socket types
	p:flag("tcp", "-t"):flag("udp", "-u"):flag("raw", "-w"):flag("unix", "-x")

	-- Selection
	p:flag("all", "-a"):flag("listening", "-l")

	-- Output formatting/details
	p:flag("numeric", "-n")
		:flag("resolve", "-r")
		:flag("no_header", "-H")
		:flag("extended", "-e")
		:flag("info", "-i")
		:flag("memory", "-m")
		:flag("timers", "-o")
		:flag("summary", "-s")

	-- Process / packet
	if opts.process or opts.packet then
		args[#args + 1] = "-p"
	end

	-- SELinux context
	if opts.context ~= nil then
		validate.non_empty_string(opts.context, "context")
		args[#args + 1] = "-Z"
		args[#args + 1] = tostring(opts.context)
	elseif opts.show_context then
		args[#args + 1] = "-Z"
	end

	p:extra("extra")
end

---Construct an ss command.
---
---`filter` is appended after options. If you need multi-token filter expressions,
---pass a `string[]` where each element is one token, e.g.:
---  {"state", "established", "(", "dport", "=", ":ssh", ")"}
---
---@param filter string|string[]|nil
---@param opts SsOpts|nil
---@return ward.Cmd
function Ss.show(filter, opts)
	ensure.bin(Ss.bin, { label = "ss binary" })

	local args = { Ss.bin }
	apply_opts(args, opts)

	if filter ~= nil then
		local ff = args_util.normalize_string_or_array(filter, "filter")
		for _, tok in ipairs(ff) do
			args[#args + 1] = tok
		end
	end

	return _cmd.cmd(table.unpack(args))
end

---Convenience: `ss -s`.
---@param opts SsOpts|nil
---@return ward.Cmd
function Ss.summary(opts)
	local o = args_util.clone_opts(opts)
	o.summary = true
	return Ss.show(nil, o)
end

---Convenience: `ss -l`.
---@param filter string|string[]|nil
---@param opts SsOpts|nil
---@return ward.Cmd
function Ss.listen(filter, opts)
	local o = args_util.clone_opts(opts)
	o.listening = true
	return Ss.show(filter, o)
end

---Convenience: `ss -a`.
---@param filter string|string[]|nil
---@param opts SsOpts|nil
---@return ward.Cmd
function Ss.all_sockets(filter, opts)
	local o = args_util.clone_opts(opts)
	o.all = true
	return Ss.show(filter, o)
end

return {
	Ss = Ss,
}
