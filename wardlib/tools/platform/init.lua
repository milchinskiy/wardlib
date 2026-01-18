-- wardlib.tools.platform
--
-- Cross-platform host/platform inspection helpers.
--
-- Goals:
--   * Provide a stable, small API for scripts to branch on OS/arch and common conventions.
--   * Avoid re-implementing Ward core: delegate to `ward.host.platform` when possible.
--
-- Non-goals:
--   * Distro abstraction (package manager selection, etc.).
--   * Deep hardware inventory (use `ward.host.resources` for that).

local validate = require("wardlib.util.validate")

local host_platform = require("ward.host.platform")
local env = require("ward.env")
local fs = require("ward.fs")

local M = {}

local function is_truthy_env(v)
	if v == nil then return false end
	v = tostring(v)
	if v == "" then return false end
	v = v:lower()
	if v == "0" or v == "false" or v == "no" or v == "off" then return false end
	return true
end

-- Common CI environment variables.
local CI_VARS = {
	"CI",
	"GITHUB_ACTIONS",
	"GITLAB_CI",
	"BITBUCKET_BUILD_NUMBER",
	"BUILDKITE",
	"CIRCLECI",
	"APPVEYOR",
	"TF_BUILD",
	"TEAMCITY_VERSION",
	"JENKINS_URL",
}

-- Returns true when the environment looks like CI.
function M.is_ci()
	for _, k in ipairs(CI_VARS) do
		if is_truthy_env(env.get(k)) then return true end
	end
	return false
end

-- Delegated OS/arch helpers (compile-time target for the Ward binary).
function M.os() return host_platform.os() end
function M.arch() return host_platform.arch() end
function M.platform() return host_platform.platform() end

function M.is_windows() return host_platform.is_windows() end
function M.is_macos() return host_platform.is_macos() end
function M.is_linux() return host_platform.is_linux() end
function M.is_unix() return host_platform.is_unix() end
function M.is_bsd() return host_platform.is_bsd() end

function M.exe_suffix() return host_platform.exe_suffix() end
function M.path_sep() return host_platform.path_sep() end
function M.env_sep() return host_platform.env_sep() end
function M.newline() return host_platform.newline() end
function M.endianness() return host_platform.endianness() end
function M.shell() return host_platform.shell() end

function M.version() return host_platform.version() end
function M.release() return host_platform.release() end
function M.hostname() return host_platform.hostname() end

-- One-shot normalized info table.
-- Adds:
--   * is_ci
--   * home
--   * tmpdir
function M.info()
	local info = host_platform.info()
	info.is_ci = M.is_ci()
	info.home = M.home()
	info.tmpdir = M.tmpdir()
	return info
end

-- Returns best-effort home directory path.
function M.home()
	local h = env.get("HOME")
	if h and #h > 0 then return h end

	-- Windows conventions
	local up = env.get("USERPROFILE")
	if up and #up > 0 then return up end

	local hd = env.get("HOMEDRIVE")
	local hp = env.get("HOMEPATH")
	if hd and #hd > 0 and hp and #hp > 0 then return hd .. hp end

	return nil
end

-- Returns best-effort temp directory path.
function M.tmpdir()
	local t = env.get("TMPDIR")
	if t and #t > 0 then return t end
	local temp = env.get("TEMP")
	if temp and #temp > 0 then return temp end
	local tmp = env.get("TMP")
	if tmp and #tmp > 0 then return tmp end

	if M.is_unix() then return "/tmp" end
	return nil
end

-- Parse the contents of an os-release file into a table.
-- Keys are normalized to lower-case snake style, e.g. ID -> id, VERSION_ID -> version_id.
function M.parse_os_release(text)
	validate.non_empty_string(text, "text")

	local out = {}

	local function unquote(v)
		v = v:gsub("^%s+", ""):gsub("%s+$", "")
		if (#v >= 2) and ((v:sub(1, 1) == '"' and v:sub(-1) == '"') or (v:sub(1, 1) == "'" and v:sub(-1) == "'")) then
			v = v:sub(2, -2)
		end
		-- Minimal escape handling for common sequences in os-release.
		v = v:gsub("\\\\n", "\n"):gsub("\\\\t", "\t"):gsub("\\\\\\\\", "\\")
		v = v:gsub('\\\\"', '"')
		return v
	end

	for line in text:gmatch("[^\n]+") do
		-- strip CR for Windows line endings
		line = line:gsub("\r$", "")
		if not line:match("^%s*#") and not line:match("^%s*$") then
			local k, v = line:match("^%s*([A-Za-z0-9_]+)%s*=%s*(.*)%s*$")
			if k and v then
				local key = k:lower()
				out[key] = unquote(v)
			end
		end
	end

	return out
end

M.linux = {}

-- Linux-only: read /etc/os-release (or specified path) and parse it.
-- Returns a table on success, or nil when not available.
function M.linux.os_release(opts)
	opts = opts or {}
	local path = opts.path or "/etc/os-release"

	if not M.is_linux() and not opts.force then
		return nil
	end

	if not fs.is_exists(path) then
		-- Some distros use /usr/lib/os-release
		local alt = "/usr/lib/os-release"
		if fs.is_exists(alt) then path = alt else return nil end
	end

	local text = fs.read(path, { mode = "text" })
	if type(text) ~= "string" or #text == 0 then return nil end
	return M.parse_os_release(text)
end

-- Best-effort: returns os-release info on Linux, otherwise nil.
function M.os_release(opts)
	return M.linux.os_release(opts)
end

return M
