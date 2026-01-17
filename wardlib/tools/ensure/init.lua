-- wardlib.tools.ensure
--
-- Explicit, fail-fast contract checks for scripts.
-- Non-goal: portability negotiation or distro abstraction.

local args_util = require("wardlib.util.args")
local validate = require("wardlib.util.validate")
local trim = require("ward.helpers.string").trim

local M = {}

local function join(list, sep)
	sep = sep or ", "
	local out = {}
	for i, v in ipairs(list) do
		out[i] = tostring(v)
	end
	return table.concat(out, sep)
end

local function is_windows(env)
	-- Best-effort:
	--  * Windows builds typically have `\\` as path separator.
	--  * Many Windows environments export OS=Windows_NT.

	local sep = package.config:sub(1, 1)
	if sep == "\\" then return true end

	return env.get("OS") == "Windows_NT"
end

local function detect_os(env, process)
	if is_windows(env) then return "windows" end

	-- Prefer uname when present. If it is not present, fall back to generic "unix".
	local uname = env.which and env.which("uname")
	if not uname then return "unix" end

	local r = process.cmd(uname, "-s"):output()
	if not r.ok then error("tools.ensure.os: failed to run uname -s", 3) end

	local v = trim(r.stdout)
	if #v == 0 then return "unix" end
	v = v:lower()

	-- Normalize common uname values
	if v == "linux" then return "linux" end
	if v == "darwin" then return "darwin" end
	if v == "freebsd" then return "freebsd" end
	if v == "openbsd" then return "openbsd" end
	if v == "netbsd" then return "netbsd" end

	return v
end

local function normalize_allowed_os(v)
	v = tostring(v):lower()
	if v == "posix" then return "unix" end
	return v
end

-- Ensure a binary exists (either explicit path or name in PATH).
-- Returns resolved path when possible.
-- @param name_or_path string
-- @param opts table|nil
function M.bin(name_or_path, opts)
	validate.non_empty_string(name_or_path, "bin")
	opts = opts or {}

	local env = require("ward.env")
	local fs = require("ward.fs")

	local label = opts.label or "binary"
	local hint = opts.hint

	local is_path = name_or_path:find("/", 1, true) or name_or_path:find("\\", 1, true)

	if is_path then
		if not fs.is_exists(name_or_path) then
			local msg = string.format("%s does not exist: %s", label, name_or_path)
			if hint then msg = msg .. "\nHint: " .. hint end
			error(msg, 2)
		end
		if not fs.is_executable(name_or_path) then
			local msg = string.format("%s is not executable: %s", label, name_or_path)
			if hint then msg = msg .. "\nHint: " .. hint end
			error(msg, 2)
		end
		return name_or_path
	end

	if not env.is_in_path(name_or_path) then
		local msg = string.format("%s not found in PATH: %s", label, name_or_path)
		if hint then msg = msg .. "\nHint: " .. hint end
		error(msg, 2)
	end

	return (env.which and env.which(name_or_path)) or name_or_path
end

-- Ensure a set of binaries are available.
-- Returns a map: { [name]=resolved_path }.
-- @param bins string|string[]
-- @param opts table|nil
function M.bins(bins, opts)
	local list = args_util.normalize_string_or_array(bins, "bins")
	local out = {}
	for _, name in ipairs(list) do
		out[name] = M.bin(name, opts)
	end
	return out
end

-- Ensure an environment variable (or variables) are set.
-- Returns value for a single key, or a map for multiple keys.
-- @param keys string|string[]
-- @param opts table|nil
function M.env(keys, opts)
	opts = opts or {}
	local env = require("ward.env")

	local allow_empty = opts.allow_empty == true
	local hint = opts.hint

	local function require_one(k)
		validate.non_empty_string(k, "env key")
		local v = env.get(k)
		if v == nil or (not allow_empty and v == "") then
			local msg = string.format("required environment variable is not set: %s", k)
			if hint then msg = msg .. "\nHint: " .. hint end
			error(msg, 3)
		end
		return v
	end

	if type(keys) == "string" then return require_one(keys) end

	assert(type(keys) == "table", "env keys must be a string or string[]")
	assert(#keys > 0, "env keys must be non-empty")

	local out = {}
	for _, k in ipairs(keys) do
		out[k] = require_one(k)
	end
	return out
end

-- Ensure the script is running with root privileges (Unix).
-- @param opts table|nil
function M.root(opts)
	opts = opts or {}
	local env = require("ward.env")
	local process = require("ward.process")

	if is_windows(env) then error("tools.ensure.root: unsupported on Windows", 2) end

	local id = env.which and env.which("id")
	if not id then error("tools.ensure.root: cannot determine uid (missing 'id' binary)", 2) end

	local r = process.cmd(id, "-u"):output()
	if not r.ok then error("tools.ensure.root: failed to run 'id -u'", 2) end

	local uid = trim(r.stdout)
	if uid ~= "0" then
		local msg = "root privileges required"
		if opts.allow_sudo_hint ~= false then msg = msg .. "\nHint: re-run with sudo (or as root)." end
		error(msg, 2)
	end

	return true
end

-- Ensure the script is running on an allowed OS.
-- @param allowed string|string[]
-- @param opts table|nil
function M.os(allowed, opts)
	opts = opts or {}
	local env = require("ward.env")
	local process = require("ward.process")

	local allowed_list = args_util.normalize_string_or_array(allowed, "os")
	local allowed_set = {}
	for _, a in ipairs(allowed_list) do
		allowed_set[normalize_allowed_os(a)] = true
	end

	local current = detect_os(env, process)
	local current_norm = normalize_allowed_os(current)

	if allowed_set[current_norm] then return current_norm end

	-- unix/posix means "anything except windows".
	if allowed_set["unix"] and current_norm ~= "windows" then return current_norm end

	local msg = string.format("unsupported OS: %s (allowed: %s)", current_norm, join(allowed_list))
	if opts.hint then msg = msg .. "\nHint: " .. opts.hint end
	error(msg, 2)
end

return M
