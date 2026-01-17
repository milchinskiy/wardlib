---@diagnostic disable: undefined-doc-name

-- systemd wrapper module
--
-- Thin wrappers around `systemctl` and `journalctl` that construct CLI
-- invocations and return `ward.process.cmd(...)` objects.
--
-- This module is intentionally minimal and does not attempt to interpret
-- output. Consumers can choose how to execute the returned commands.

local _cmd = require("ward.process")
local args_util = require("wardlib.util.args")
local ensure = require("wardlib.tools.ensure")

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
	args_util.parser(args, opts):flag("user", "--user")
end

---Start a unit.
---@param unit string
---@param opts SystemdCommonOpts|nil
---@return ward.Cmd
function Systemd.start(unit, opts)
	ensure.bin(Systemd.systemctl_bin, { label = "systemctl binary" })
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
	ensure.bin(Systemd.systemctl_bin, { label = "systemctl binary" })
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
	ensure.bin(Systemd.systemctl_bin, { label = "systemctl binary" })
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
	ensure.bin(Systemd.systemctl_bin, { label = "systemctl binary" })
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
	ensure.bin(Systemd.systemctl_bin, { label = "systemctl binary" })
	validate_unit(unit)
	opts = opts or {}
	local args = { Systemd.systemctl_bin }
	apply_user_flag(args, opts)
	args[#args + 1] = "enable"
	args_util.parser(args, opts):flag("now", "--now")
	args[#args + 1] = unit
	return _cmd.cmd(table.unpack(args))
end

---Disable a unit.
---@param unit string
---@param opts SystemdEnableDisableOpts|nil
---@return ward.Cmd
function Systemd.disable(unit, opts)
	ensure.bin(Systemd.systemctl_bin, { label = "systemctl binary" })
	validate_unit(unit)
	opts = opts or {}
	local args = { Systemd.systemctl_bin }
	apply_user_flag(args, opts)
	args[#args + 1] = "disable"
	args_util.parser(args, opts):flag("now", "--now")
	args[#args + 1] = unit
	return _cmd.cmd(table.unpack(args))
end

---Check whether unit is active.
---@param unit string
---@param opts SystemdCommonOpts|nil
---@return ward.Cmd
function Systemd.is_active(unit, opts)
	ensure.bin(Systemd.systemctl_bin, { label = "systemctl binary" })
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
	ensure.bin(Systemd.systemctl_bin, { label = "systemctl binary" })
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
	ensure.bin(Systemd.systemctl_bin, { label = "systemctl binary" })
	validate_unit(unit)
	opts = opts or {}
	local args = { Systemd.systemctl_bin }
	apply_user_flag(args, opts)
	args[#args + 1] = "status"

	local no_pager = opts.no_pager
	if no_pager == nil then no_pager = true end
	local eff = { no_pager = no_pager, full = opts.full }

	args_util.parser(args, eff):flag("no_pager", "--no-pager"):flag("full", "--full")

	args[#args + 1] = unit
	return _cmd.cmd(table.unpack(args))
end

---Reload systemd manager configuration.
---@param opts SystemdCommonOpts|nil
---@return ward.Cmd
function Systemd.daemon_reload(opts)
	ensure.bin(Systemd.systemctl_bin, { label = "systemctl binary" })
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
	ensure.bin(Systemd.journalctl_bin, { label = "journalctl binary" })
	opts = opts or {}

	if unit ~= nil then validate_unit(unit) end

	local no_pager = opts.no_pager
	if no_pager == nil then no_pager = true end

	local eff = {
		user = opts.user,
		no_pager = no_pager,
		unit = unit,
		follow = opts.follow,
		lines = opts.lines,
		since = opts.since,
		["until"] = opts["until"],
		priority = opts.priority,
		output = opts.output,
	}

	local args = { Systemd.journalctl_bin }
	args_util
		.parser(args, eff)
		:flag("user", "--user")
		:flag("no_pager", "--no-pager")
		:value("unit", "-u", {
			validate = function(v) validate_unit(v) end,
		})
		:flag("follow", "-f")
		:value_number("lines", "-n", { integer = true, non_negative = true })
		:value_string("since", "--since", "since")
		:value_string("until", "--until", "until")
		:value_string("priority", "-p", "priority")
		:value_string("output", "-o", "output")

	return _cmd.cmd(table.unpack(args))
end

return {
	Systemd = Systemd,
}
