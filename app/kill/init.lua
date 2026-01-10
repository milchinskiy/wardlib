---@diagnostic disable: undefined-doc-name

-- kill wrapper module
--
-- Thin wrappers around:
--   * kill
--   * killall
--   * pkill
--
-- Wrappers construct `ward.process.cmd(...)` invocations; they do not parse output.

local _cmd = require("ward.process")
local validate = require("util.validate")
local args_util = require("util.args")

---@alias Signal string|number

---@class KillOpts
---@field signal Signal? Signal name (e.g. "TERM", "SIGKILL") or number (e.g. 9)
---@field list boolean? `-l` list signals (ignores pids)
---@field table boolean? `-L` (some kill impls) list signals in a table
---@field extra string[]? Extra args appended after modeled options

---@class KillallOpts
---@field signal Signal? `-s <sig>`
---@field exact boolean? `-e` exact match
---@field ignore_case boolean? `-I` ignore case
---@field interactive boolean? `-i` ask before killing
---@field wait boolean? `-w` wait for processes to die
---@field regexp boolean? `-r` interpret names as regex
---@field user string? `-u <user>`
---@field verbose boolean? `-v`
---@field quiet boolean? `-q`
---@field extra string[]? Extra args appended after modeled options

---@class PkillOpts
---@field signal Signal? `-<sig>` or `-signal` modeled as `-<sig>`
---@field full boolean? `-f` match against full command line
---@field exact boolean? `-x` match whole name
---@field newest boolean? `-n` select newest
---@field oldest boolean? `-o` select oldest
---@field parent number? `-P <ppid>`
---@field group number? `-g <pgrp>`
---@field session number? `-s <sid>`
---@field terminal string? `-t <tty>`
---@field user string? `-u <user>`
---@field uid number? `-U <uid>`
---@field euid number? `-e <euid>` (procps)
---@field invert boolean? `-v` invert match
---@field count boolean? `-c` count matches
---@field list_name boolean? `-l` list pid and name
---@field list_full boolean? `-a` list full command line (procps)
---@field delimiter string? `-d <delim>` (procps)
---@field extra string[]? Extra args appended after modeled options

---@class Kill
---@field kill_bin string
---@field killall_bin string
---@field pkill_bin string
---@field kill fun(pids: number|number[]|string|string[]|nil, opts: KillOpts|nil): ward.Cmd
---@field killall fun(names: string|string[]|nil, opts: KillallOpts|nil): ward.Cmd
---@field pkill fun(pattern: string|nil, opts: PkillOpts|nil): ward.Cmd
---@field by_name fun(name: string, sig: Signal|nil): ward.Cmd Convenience: killall -s <sig> <name>
---@field by_pattern fun(pattern: string, sig: Signal|nil, full: boolean|nil): ward.Cmd Convenience: pkill [-f] -<sig> <pattern>
---@field pid fun(pid: number|string, sig: Signal|nil): ward.Cmd Convenience: kill -s <sig> <pid>
local Kill = {
	kill_bin = "kill",
	killall_bin = "killall",
	pkill_bin = "pkill",
}

---@param v any
---@param label string
local function validate_number(v, label)
	assert(type(v) == "number", label .. " must be a number")
end

---@param sig Signal
---@return string
local function normalize_signal(sig)
	local t = type(sig)
	if t == "number" then
		return tostring(sig)
	end
	if t == "string" then
		validate.non_empty_string(sig, "signal")
		-- allow "TERM" or "SIGTERM"; do not force prefix
		return sig
	end
	error("signal must be string or number")
end

---@param args string[]
---@param opts KillOpts|nil
local function apply_kill_opts(args, opts)
	opts = opts or {}
	if opts.list then
		table.insert(args, "-l")
	end
	if opts.table then
		table.insert(args, "-L")
	end
	if opts.signal ~= nil then
		-- many kill implementations accept: kill -s SIGTERM pid
		local sig = normalize_signal(opts.signal)
		table.insert(args, "-s")
		table.insert(args, sig)
	end
	args_util.append_extra(args, opts.extra)
end

---@param args string[]
---@param opts KillallOpts|nil
local function apply_killall_opts(args, opts)
	opts = opts or {}
	if opts.signal ~= nil then
		local sig = normalize_signal(opts.signal)
		table.insert(args, "-s")
		table.insert(args, sig)
	end
	if opts.exact then
		table.insert(args, "-e")
	end
	if opts.ignore_case then
		table.insert(args, "-I")
	end
	if opts.interactive then
		table.insert(args, "-i")
	end
	if opts.wait then
		table.insert(args, "-w")
	end
	if opts.regexp then
		table.insert(args, "-r")
	end
	if opts.verbose then
		table.insert(args, "-v")
	end
	if opts.quiet then
		table.insert(args, "-q")
	end
	if opts.user ~= nil then
		validate.non_empty_string(opts.user, "user")
		table.insert(args, "-u")
		table.insert(args, opts.user)
	end
	args_util.append_extra(args, opts.extra)
end

---@param args string[]
---@param opts PkillOpts|nil
local function apply_pkill_opts(args, opts)
	opts = opts or {}
	if opts.signal ~= nil then
		local sig = normalize_signal(opts.signal)
		-- pkill supports -<sig> or -SIGTERM. We'll use the compact -<sig> form.
		table.insert(args, "-" .. sig)
	end
	if opts.full then
		table.insert(args, "-f")
	end
	if opts.exact then
		table.insert(args, "-x")
	end
	if opts.newest then
		table.insert(args, "-n")
	end
	if opts.oldest then
		table.insert(args, "-o")
	end
	if opts.invert then
		table.insert(args, "-v")
	end
	if opts.count then
		table.insert(args, "-c")
	end
	if opts.list_name then
		table.insert(args, "-l")
	end
	if opts.list_full then
		table.insert(args, "-a")
	end
	if opts.parent ~= nil then
		validate_number(opts.parent, "parent")
		table.insert(args, "-P")
		table.insert(args, tostring(opts.parent))
	end
	if opts.group ~= nil then
		validate_number(opts.group, "group")
		table.insert(args, "-g")
		table.insert(args, tostring(opts.group))
	end
	if opts.session ~= nil then
		validate_number(opts.session, "session")
		table.insert(args, "-s")
		table.insert(args, tostring(opts.session))
	end
	if opts.terminal ~= nil then
		validate.non_empty_string(opts.terminal, "terminal")
		table.insert(args, "-t")
		table.insert(args, opts.terminal)
	end
	if opts.user ~= nil then
		validate.non_empty_string(opts.user, "user")
		table.insert(args, "-u")
		table.insert(args, opts.user)
	end
	if opts.uid ~= nil then
		validate_number(opts.uid, "uid")
		table.insert(args, "-U")
		table.insert(args, tostring(opts.uid))
	end
	if opts.euid ~= nil then
		validate_number(opts.euid, "euid")
		table.insert(args, "-e")
		table.insert(args, tostring(opts.euid))
	end
	if opts.delimiter ~= nil then
		validate.non_empty_string(opts.delimiter, "delimiter")
		table.insert(args, "-d")
		table.insert(args, opts.delimiter)
	end
	args_util.append_extra(args, opts.extra)
end

---Construct a kill command.
---
---If `pids` is nil, kill will run with only the configured options (useful for `-l`).
---@param pids number|number[]|string|string[]|nil
---@param opts KillOpts|nil
---@return ward.Cmd
function Kill.kill(pids, opts)
	validate.bin(Kill.kill_bin, "kill binary")

	local args = { Kill.kill_bin }
	apply_kill_opts(args, opts)

	if pids ~= nil then
		local tp = type(pids)
		if tp == "number" then
			table.insert(args, tostring(pids))
		elseif tp == "string" then
			validate.non_empty_string(pids, "pid")
			table.insert(args, pids)
		elseif tp == "table" then
			assert(#pids > 0, "pids list must be non-empty")
			for _, pid in ipairs(pids) do
				local tpid = type(pid)
				if tpid == "number" then
					table.insert(args, tostring(pid))
				elseif tpid == "string" then
					validate.non_empty_string(pid, "pid")
					table.insert(args, pid)
				else
					error("pid must be number or string")
				end
			end
		else
			error("pids must be number, string, array, or nil")
		end
	end

	return _cmd.cmd(table.unpack(args))
end

---Construct a killall command.
---
---If `names` is nil, killall will run with only the configured options.
---@param names string|string[]|nil
---@param opts KillallOpts|nil
---@return ward.Cmd
function Kill.killall(names, opts)
	validate.bin(Kill.killall_bin, "killall binary")

	local args = { Kill.killall_bin }
	apply_killall_opts(args, opts)

	if names ~= nil then
		if type(names) == "string" then
			validate.non_empty_string(names, "name")
			table.insert(args, names)
		elseif type(names) == "table" then
			assert(#names > 0, "names list must be non-empty")
			for _, n in ipairs(names) do
				validate.non_empty_string(n, "name")
				table.insert(args, n)
			end
		else
			error("names must be string, string[], or nil")
		end
	end

	return _cmd.cmd(table.unpack(args))
end

---Construct a pkill command.
---
---If `pattern` is nil, pkill will run with only options (useful for error cases or `-l`/`-c` with other selectors).
---@param pattern string|nil
---@param opts PkillOpts|nil
---@return ward.Cmd
function Kill.pkill(pattern, opts)
	validate.bin(Kill.pkill_bin, "pkill binary")

	local args = { Kill.pkill_bin }
	apply_pkill_opts(args, opts)

	if pattern ~= nil then
		validate.non_empty_string(pattern, "pattern")
		table.insert(args, pattern)
	end

	return _cmd.cmd(table.unpack(args))
end

---Convenience: kill by pid.
---@param pid number|string
---@param sig Signal|nil
---@return ward.Cmd
function Kill.pid(pid, sig)
	local opts = {}
	if sig ~= nil then
		opts.signal = sig
	end
	return Kill.kill(pid, opts)
end

---Convenience: kill all processes by name.
---@param name string
---@param sig Signal|nil
---@return ward.Cmd
function Kill.by_name(name, sig)
	validate.non_empty_string(name, "name")
	local opts = {}
	if sig ~= nil then
		opts.signal = sig
	end
	return Kill.killall(name, opts)
end

---Convenience: kill processes matching a pattern.
---@param pattern string
---@param sig Signal|nil
---@param full boolean|nil
---@return ward.Cmd
function Kill.by_pattern(pattern, sig, full)
	validate.non_empty_string(pattern, "pattern")
	local opts = {}
	if sig ~= nil then
		opts.signal = sig
	end
	if full ~= nil then
		opts.full = full
	end
	return Kill.pkill(pattern, opts)
end

return {
	Kill = Kill,
}
