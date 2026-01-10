---@diagnostic disable: undefined-doc-name

-- playerctl wrapper module
--
-- Thin wrappers around `playerctl` that construct CLI invocations and return
-- `ward.process.cmd(...)` objects.

local _cmd = require("ward.process")
local validate = require("util.validate")
local args_util = require("util.args")

---@class PlayerctlOpts
---@field player string? `--player <name>`
---@field all_players boolean? `--all-players`
---@field ignore string[]? `--ignore-player <name>` repeated
---@field extra string[]? Extra args appended before subcommand

---@class PlayerctlMetadataOpts: PlayerctlOpts
---@field format string? `--format <fmt>`

---@class Playerctl
---@field bin string
---@field cmd fun(subcmd: string, argv: string[]|nil, opts: PlayerctlOpts|nil): ward.Cmd
---@field play fun(opts: PlayerctlOpts|nil): ward.Cmd
---@field pause fun(opts: PlayerctlOpts|nil): ward.Cmd
---@field play_pause fun(opts: PlayerctlOpts|nil): ward.Cmd
---@field next fun(opts: PlayerctlOpts|nil): ward.Cmd
---@field previous fun(opts: PlayerctlOpts|nil): ward.Cmd
---@field stop fun(opts: PlayerctlOpts|nil): ward.Cmd
---@field status fun(opts: PlayerctlOpts|nil): ward.Cmd
---@field metadata fun(opts: PlayerctlMetadataOpts|nil): ward.Cmd
local Playerctl = {
	bin = "playerctl",
}

---@param s any
---@param label string
local function validate_token(s, label)
	assert(type(s) == "string" and #s > 0, label .. " must be a non-empty string")
	assert(not s:find("%s"), label .. " must not contain whitespace: " .. tostring(s))
	assert(s:sub(1, 1) ~= "-", label .. " must not start with '-': " .. tostring(s))
end

---@param args string[]
---@param opts PlayerctlOpts|nil
local function apply_opts(args, opts)
	opts = opts or {}
	if opts.player ~= nil then
		validate_token(opts.player, "player")
		table.insert(args, "--player")
		table.insert(args, opts.player)
	end
	if opts.all_players then
		table.insert(args, "--all-players")
	end
	if opts.ignore ~= nil then
		assert(type(opts.ignore) == "table", "ignore must be an array")
		for _, p in ipairs(opts.ignore) do
			validate_token(p, "ignore")
			table.insert(args, "--ignore-player")
			table.insert(args, p)
		end
	end
	args_util.append_extra(args, opts.extra)
end

---@param subcmd string
---@param argv string[]|nil
---@param opts PlayerctlOpts|nil
---@return ward.Cmd
function Playerctl.cmd(subcmd, argv, opts)
	validate.bin(Playerctl.bin, 'playerctl binary')
	validate_token(subcmd, "subcmd")
	local args = { Playerctl.bin }
	apply_opts(args, opts)
	table.insert(args, subcmd)
	if argv ~= nil then
		for _, v in ipairs(argv) do
			table.insert(args, tostring(v))
		end
	end
	return _cmd.cmd(table.unpack(args))
end

function Playerctl.play(opts)
	return Playerctl.cmd("play", nil, opts)
end

function Playerctl.pause(opts)
	return Playerctl.cmd("pause", nil, opts)
end

function Playerctl.play_pause(opts)
	return Playerctl.cmd("play-pause", nil, opts)
end

function Playerctl.next(opts)
	return Playerctl.cmd("next", nil, opts)
end

function Playerctl.previous(opts)
	return Playerctl.cmd("previous", nil, opts)
end

function Playerctl.stop(opts)
	return Playerctl.cmd("stop", nil, opts)
end

function Playerctl.status(opts)
	return Playerctl.cmd("status", nil, opts)
end

---`playerctl metadata [--format <fmt>]`
---@param opts PlayerctlMetadataOpts|nil
---@return ward.Cmd
function Playerctl.metadata(opts)
	opts = opts or {}
	local local_argv = {}
	if opts.format ~= nil then
		assert(type(opts.format) == "string" and #opts.format > 0, "format must be a non-empty string")
		table.insert(local_argv, "--format")
		table.insert(local_argv, opts.format)
	end
	-- place format before subcommand by using opts.extra? playerctl allows global options
	-- but `--format` is specific to metadata; we append after subcmd per playerctl syntax.
	return Playerctl.cmd("metadata", local_argv, opts)
end

return {
	Playerctl = Playerctl,
}
