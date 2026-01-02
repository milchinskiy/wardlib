---@diagnostic disable: undefined-doc-name

-- systemd wrapper module
--
-- Thin wrappers around `systemctl` and `journalctl` that construct CLI
-- invocations and return `ward.process.cmd(...)` objects.
--
-- This module is intentionally minimal and does not attempt to interpret
-- output. Consumers can choose how to execute the returned commands.

local _cmd = require("ward.process")
local _env = require("ward.env")
local _fs = require("ward.fs")

---@class SystemdCommonOpts
---@field user boolean? Use per-user systemd manager (`--user`)

---@class SystemdEnableDisableOpts: SystemdCommonOpts
---@field now boolean? Start/stop unit immediately (`--now`)

---@class SystemdStatusOpts: SystemdCommonOpts
---@field no_pager boolean? Add `--no-pager` (default true)
---@field full boolean? Add `--full`

---@class SystemdJournalOpts: SystemdCommonOpts
---@field follow boolean? `-f`
---@field lines integer? `-n <lines>`
---@field since string? `--since <time>`
---@field until string? `--until <time>`
---@field priority string? `-p <prio>` (e.g. "err", "warning", "info", "3")
---@field no_pager boolean? Add `--no-pager` (default true)
---@field output string? `-o <format>` (e.g. "short-iso", "cat", "json")

---@class Systemd
---@field systemctl_bin string Executable name or path to `systemctl`
---@field journalctl_bin string Executable name or path to `journalctl`
---@field start fun(unit: string, opts: SystemdCommonOpts|nil): ward.Cmd
---@field stop fun(unit: string, opts: SystemdCommonOpts|nil): ward.Cmd
---@field restart fun(unit: string, opts: SystemdCommonOpts|nil): ward.Cmd
---@field reload fun(unit: string, opts: SystemdCommonOpts|nil): ward.Cmd
---@field enable fun(unit: string, opts: SystemdEnableDisableOpts|nil): ward.Cmd
---@field disable fun(unit: string, opts: SystemdEnableDisableOpts|nil): ward.Cmd
---@field is_active fun(unit: string, opts: SystemdCommonOpts|nil): ward.Cmd
---@field is_enabled fun(unit: string, opts: SystemdCommonOpts|nil): ward.Cmd
---@field status fun(unit: string, opts: SystemdStatusOpts|nil): ward.Cmd
---@field daemon_reload fun(opts: SystemdCommonOpts|nil): ward.Cmd
---@field journal fun(unit: string|nil, opts: SystemdJournalOpts|nil): ward.Cmd
local Systemd = {
	systemctl_bin = "systemctl",
	journalctl_bin = "journalctl",
}

---Validate binary name/path.
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

---Validate a unit name.
---@param unit string
local function validate_unit(unit)
	assert(type(unit) == "string" and #unit > 0, "unit must be a non-empty string")
	assert(not unit:find("%s"), "unit must not contain whitespace: " .. tostring(unit))
	-- Avoid accidental flag injection like "-f" passed as unit.
	assert(unit:sub(1, 1) ~= "-", "unit must not start with '-': " .. tostring(unit))
end

---@param args table
---@param opts SystemdCommonOpts|nil
local function apply_user_flag(args, opts)
	opts = opts or {}
	if opts.user then
		table.insert(args, "--user")
	end
end

---Start a unit.
---@param unit string
---@param opts SystemdCommonOpts|nil
---@return ward.Cmd
function Systemd.start(unit, opts)
	validate_bin(Systemd.systemctl_bin, "systemctl")
	validate_unit(unit)
	local args = { Systemd.systemctl_bin }
	apply_user_flag(args, opts)
	table.insert(args, "start")
	table.insert(args, unit)
	return _cmd.cmd(table.unpack(args))
end

---Stop a unit.
---@param unit string
---@param opts SystemdCommonOpts|nil
---@return ward.Cmd
function Systemd.stop(unit, opts)
	validate_bin(Systemd.systemctl_bin, "systemctl")
	validate_unit(unit)
	local args = { Systemd.systemctl_bin }
	apply_user_flag(args, opts)
	table.insert(args, "stop")
	table.insert(args, unit)
	return _cmd.cmd(table.unpack(args))
end

---Restart a unit.
---@param unit string
---@param opts SystemdCommonOpts|nil
---@return ward.Cmd
function Systemd.restart(unit, opts)
	validate_bin(Systemd.systemctl_bin, "systemctl")
	validate_unit(unit)
	local args = { Systemd.systemctl_bin }
	apply_user_flag(args, opts)
	table.insert(args, "restart")
	table.insert(args, unit)
	return _cmd.cmd(table.unpack(args))
end

---Reload a unit.
---@param unit string
---@param opts SystemdCommonOpts|nil
---@return ward.Cmd
function Systemd.reload(unit, opts)
	validate_bin(Systemd.systemctl_bin, "systemctl")
	validate_unit(unit)
	local args = { Systemd.systemctl_bin }
	apply_user_flag(args, opts)
	table.insert(args, "reload")
	table.insert(args, unit)
	return _cmd.cmd(table.unpack(args))
end

---Enable a unit.
---@param unit string
---@param opts SystemdEnableDisableOpts|nil
---@return ward.Cmd
function Systemd.enable(unit, opts)
	validate_bin(Systemd.systemctl_bin, "systemctl")
	validate_unit(unit)
	opts = opts or {}
	local args = { Systemd.systemctl_bin }
	apply_user_flag(args, opts)
	table.insert(args, "enable")
	if opts.now then
		table.insert(args, "--now")
	end
	table.insert(args, unit)
	return _cmd.cmd(table.unpack(args))
end

---Disable a unit.
---@param unit string
---@param opts SystemdEnableDisableOpts|nil
---@return ward.Cmd
function Systemd.disable(unit, opts)
	validate_bin(Systemd.systemctl_bin, "systemctl")
	validate_unit(unit)
	opts = opts or {}
	local args = { Systemd.systemctl_bin }
	apply_user_flag(args, opts)
	table.insert(args, "disable")
	if opts.now then
		table.insert(args, "--now")
	end
	table.insert(args, unit)
	return _cmd.cmd(table.unpack(args))
end

---Check whether unit is active.
---@param unit string
---@param opts SystemdCommonOpts|nil
---@return ward.Cmd
function Systemd.is_active(unit, opts)
	validate_bin(Systemd.systemctl_bin, "systemctl")
	validate_unit(unit)
	local args = { Systemd.systemctl_bin }
	apply_user_flag(args, opts)
	table.insert(args, "is-active")
	table.insert(args, unit)
	return _cmd.cmd(table.unpack(args))
end

---Check whether unit is enabled.
---@param unit string
---@param opts SystemdCommonOpts|nil
---@return ward.Cmd
function Systemd.is_enabled(unit, opts)
	validate_bin(Systemd.systemctl_bin, "systemctl")
	validate_unit(unit)
	local args = { Systemd.systemctl_bin }
	apply_user_flag(args, opts)
	table.insert(args, "is-enabled")
	table.insert(args, unit)
	return _cmd.cmd(table.unpack(args))
end

---Show unit status.
---@param unit string
---@param opts SystemdStatusOpts|nil
---@return ward.Cmd
function Systemd.status(unit, opts)
	validate_bin(Systemd.systemctl_bin, "systemctl")
	validate_unit(unit)
	opts = opts or {}
	local args = { Systemd.systemctl_bin }
	apply_user_flag(args, opts)
	table.insert(args, "status")

	local no_pager = opts.no_pager
	if no_pager == nil then
		no_pager = true
	end
	if no_pager then
		table.insert(args, "--no-pager")
	end
	if opts.full then
		table.insert(args, "--full")
	end

	table.insert(args, unit)
	return _cmd.cmd(table.unpack(args))
end

---Reload systemd manager configuration.
---@param opts SystemdCommonOpts|nil
---@return ward.Cmd
function Systemd.daemon_reload(opts)
	validate_bin(Systemd.systemctl_bin, "systemctl")
	local args = { Systemd.systemctl_bin }
	apply_user_flag(args, opts)
	table.insert(args, "daemon-reload")
	return _cmd.cmd(table.unpack(args))
end

---Query journal output.
---@param unit string|nil
---@param opts SystemdJournalOpts|nil
---@return ward.Cmd
function Systemd.journal(unit, opts)
	validate_bin(Systemd.journalctl_bin, "journalctl")
	opts = opts or {}

	if unit ~= nil then
		validate_unit(unit)
	end

	local args = { Systemd.journalctl_bin }
	apply_user_flag(args, opts)

	local no_pager = opts.no_pager
	if no_pager == nil then
		no_pager = true
	end
	if no_pager then
		table.insert(args, "--no-pager")
	end

	if unit ~= nil then
		table.insert(args, "-u")
		table.insert(args, unit)
	end

	if opts.follow then
		table.insert(args, "-f")
	end

	if opts.lines ~= nil then
		assert(
			type(opts.lines) == "number" and opts.lines >= 0 and math.floor(opts.lines) == opts.lines,
			"lines must be a non-negative integer"
		)
		table.insert(args, "-n")
		table.insert(args, tostring(opts.lines))
	end

	if opts.since ~= nil then
		assert(type(opts.since) == "string" and #opts.since > 0, "since must be a non-empty string")
		table.insert(args, "--since")
		table.insert(args, opts.since)
	end

	if opts["until"] ~= nil then
		assert(type(opts["until"]) == "string" and #opts["until"] > 0, "until must be a non-empty string")
		table.insert(args, "--until")
		table.insert(args, opts["until"])
	end

	if opts.priority ~= nil then
		assert(type(opts.priority) == "string" and #opts.priority > 0, "priority must be a non-empty string")
		table.insert(args, "-p")
		table.insert(args, opts.priority)
	end

	if opts.output ~= nil then
		assert(type(opts.output) == "string" and #opts.output > 0, "output must be a non-empty string")
		table.insert(args, "-o")
		table.insert(args, opts.output)
	end

	return _cmd.cmd(table.unpack(args))
end

return {
	Systemd = Systemd,
}
