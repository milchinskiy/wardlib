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
	if opts.inet4 then
		args[#args + 1] = "-4"
	end
	if opts.inet6 then
		args[#args + 1] = "-6"
	end
	if opts.family ~= nil then
		validate.not_flag(opts.family, "family")
		args[#args + 1] = "-f"
		args[#args + 1] = tostring(opts.family)
	end

	-- Socket types
	if opts.tcp then
		args[#args + 1] = "-t"
	end
	if opts.udp then
		args[#args + 1] = "-u"
	end
	if opts.raw then
		args[#args + 1] = "-w"
	end
	if opts.unix then
		args[#args + 1] = "-x"
	end

	-- Selection
	if opts.all then
		args[#args + 1] = "-a"
	end
	if opts.listening then
		args[#args + 1] = "-l"
	end

	-- Output formatting/details
	if opts.numeric then
		args[#args + 1] = "-n"
	end
	if opts.resolve then
		args[#args + 1] = "-r"
	end
	if opts.no_header then
		args[#args + 1] = "-H"
	end
	if opts.extended then
		args[#args + 1] = "-e"
	end
	if opts.info then
		args[#args + 1] = "-i"
	end
	if opts.memory then
		args[#args + 1] = "-m"
	end
	if opts.timers then
		args[#args + 1] = "-o"
	end
	if opts.summary then
		args[#args + 1] = "-s"
	end

	-- Process / packet sockets
	-- NOTE: ss uses `-p` for processes, and some builds use `-p` for packet sockets.
	-- We support the common meaning (process). If the caller explicitly sets
	-- `packet = true`, we still emit `-p` because that's what they asked for.
	-- Avoid setting both.
	if opts.process and opts.packet then
		error("process and packet are mutually exclusive")
	end
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

	args_util.append_extra(args, opts.extra)
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
	validate.bin(Ss.bin, "ss binary")

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
