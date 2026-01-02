---@diagnostic disable: undefined-doc-name

-- ssh/scp wrapper module
--
-- Thin wrappers around `ssh` and `scp` that construct CLI invocations and
-- return `ward.process.cmd(...)` objects.
--
-- This module intentionally does not parse output.

local _cmd = require("ward.process")
local _env = require("ward.env")
local _fs = require("ward.fs")

---@class SshCommonOpts
---@field user string? Username (prepended as `user@host`)
---@field port integer? Port (`ssh -p`, `scp -P`)
---@field identity_file string? Identity file (`-i <path>`)
---@field batch boolean? `-o BatchMode=yes`
---@field strict_host_key_checking boolean|string? `-o StrictHostKeyChecking=<...>` (true->yes, false->no, or pass "accept-new")
---@field known_hosts_file string? `-o UserKnownHostsFile=<path>`
---@field connect_timeout integer? `-o ConnectTimeout=<seconds>`
---@field extra string[]? Extra args appended before host/paths

---@class ScpOpts: SshCommonOpts
---@field recursive boolean? `-r`
---@field preserve_times boolean? `-p`
---@field compress boolean? `-C`
---@field quiet boolean? `-q`

---@class Ssh
---@field ssh_bin string Executable name or path to `ssh`
---@field scp_bin string Executable name or path to `scp`
---@field target fun(host: string, opts: SshCommonOpts|nil): string
---@field remote fun(host: string, path: string, opts: SshCommonOpts|nil): string
---@field exec fun(host: string, remote: string|string[]|nil, opts: SshCommonOpts|nil): ward.Cmd
---@field scp fun(src: string, dst: string, opts: ScpOpts|nil): ward.Cmd
---@field copy_to fun(host: string, local_path: string, remote_path: string, opts: ScpOpts|nil): ward.Cmd
---@field copy_from fun(host: string, remote_path: string, local_path: string, opts: ScpOpts|nil): ward.Cmd
local Ssh = {
	ssh_bin = "ssh",
	scp_bin = "scp",
}

---@param bin string
---@param label string
local function validate_bin(bin, label)
	assert(type(bin) == "string" and #bin > 0, label .. " binary is not set")
	if bin:find("/", 1, true) then
		assert(_fs.is_exists(bin), string.format("%s binary does not exist: %s", label, bin))
		assert(_fs.is_executable(bin), string.format("%s binary is not executable: %s", label, bin))
	else
		assert(_env.is_in_path(bin), string.format("%s binary is not in PATH: %s", label, bin))
	end
end

---@param host string
local function validate_host(host)
	assert(type(host) == "string" and #host > 0, "host must be a non-empty string")
	assert(not host:find("%s"), "host must not contain whitespace: " .. tostring(host))
	assert(host:sub(1, 1) ~= "-", "host must not start with '-': " .. tostring(host))
end

---@param s string?
---@param label string
local function validate_not_empty(s, label)
	assert(type(s) == "string" and #s > 0, label .. " must be a non-empty string")
end

---@param v any
---@param label string
local function validate_int(v, label)
	assert(type(v) == "number" and v > 0 and math.floor(v) == v, label .. " must be a positive integer")
end

---@param args string[]
---@param opts SshCommonOpts|nil
---@param port_flag string
local function apply_common(args, opts, port_flag)
	opts = opts or {}

	if opts.port ~= nil then
		validate_int(opts.port, "port")
		table.insert(args, port_flag)
		table.insert(args, tostring(opts.port))
	end

	if opts.identity_file ~= nil then
		validate_not_empty(opts.identity_file, "identity_file")
		table.insert(args, "-i")
		table.insert(args, opts.identity_file)
	end

	if opts.batch then
		table.insert(args, "-o")
		table.insert(args, "BatchMode=yes")
	end

	if opts.strict_host_key_checking ~= nil then
		local v = opts.strict_host_key_checking
		local val
		if type(v) == "boolean" then
			val = v and "yes" or "no"
		else
			validate_not_empty(v, "strict_host_key_checking")
			val = v
		end
		table.insert(args, "-o")
		table.insert(args, "StrictHostKeyChecking=" .. val)
	end

	if opts.known_hosts_file ~= nil then
		validate_not_empty(opts.known_hosts_file, "known_hosts_file")
		table.insert(args, "-o")
		table.insert(args, "UserKnownHostsFile=" .. opts.known_hosts_file)
	end

	if opts.connect_timeout ~= nil then
		validate_int(opts.connect_timeout, "connect_timeout")
		table.insert(args, "-o")
		table.insert(args, "ConnectTimeout=" .. tostring(opts.connect_timeout))
	end

	if opts.extra ~= nil then
		assert(type(opts.extra) == "table", "extra must be an array of strings")
		for _, v in ipairs(opts.extra) do
			table.insert(args, tostring(v))
		end
	end
end

---Build target string `user@host` (or just host).
---@param host string
---@param opts SshCommonOpts|nil
---@return string
function Ssh.target(host, opts)
	validate_host(host)
	opts = opts or {}
	if opts.user ~= nil then
		validate_not_empty(opts.user, "user")
		return opts.user .. "@" .. host
	end
	return host
end

---Build remote path string `user@host:/path`.
---@param host string
---@param path string
---@param opts SshCommonOpts|nil
---@return string
function Ssh.remote(host, path, opts)
	validate_not_empty(path, "path")
	return Ssh.target(host, opts) .. ":" .. path
end

---Construct an `ssh` command.
---
---`remote` may be:
---  * nil           -> interactive session
---  * string        -> passed as a single argument
---  * string[]      -> appended as individual arguments
---@param host string
---@param remote string|string[]|nil
---@param opts SshCommonOpts|nil
---@return ward.Cmd
function Ssh.exec(host, remote, opts)
	validate_bin(Ssh.ssh_bin, "ssh")
	validate_host(host)
	opts = opts or {}

	local args = { Ssh.ssh_bin }
	apply_common(args, opts, "-p")

	table.insert(args, Ssh.target(host, opts))

	if remote ~= nil then
		local t = type(remote)
		if t == "string" then
			table.insert(args, remote)
		elseif t == "table" then
			for _, v in ipairs(remote) do
				table.insert(args, tostring(v))
			end
		else
			error("remote must be string, string[] or nil")
		end
	end

	return _cmd.cmd(table.unpack(args))
end

---Construct an `scp` command.
---@param src string
---@param dst string
---@param opts ScpOpts|nil
---@return ward.Cmd
function Ssh.scp(src, dst, opts)
	validate_bin(Ssh.scp_bin, "scp")
	validate_not_empty(src, "src")
	validate_not_empty(dst, "dst")
	opts = opts or {}

	local args = { Ssh.scp_bin }
	apply_common(args, opts, "-P")

	if opts.recursive then
		table.insert(args, "-r")
	end
	if opts.preserve_times then
		table.insert(args, "-p")
	end
	if opts.compress then
		table.insert(args, "-C")
	end
	if opts.quiet then
		table.insert(args, "-q")
	end

	table.insert(args, src)
	table.insert(args, dst)
	return _cmd.cmd(table.unpack(args))
end

---Copy local -> remote via scp.
---@param host string
---@param local_path string
---@param remote_path string
---@param opts ScpOpts|nil
---@return ward.Cmd
function Ssh.copy_to(host, local_path, remote_path, opts)
	return Ssh.scp(local_path, Ssh.remote(host, remote_path, opts), opts)
end

---Copy remote -> local via scp.
---@param host string
---@param remote_path string
---@param local_path string
---@param opts ScpOpts|nil
---@return ward.Cmd
function Ssh.copy_from(host, remote_path, local_path, opts)
	return Ssh.scp(Ssh.remote(host, remote_path, opts), local_path, opts)
end

return {
	Ssh = Ssh,
}
