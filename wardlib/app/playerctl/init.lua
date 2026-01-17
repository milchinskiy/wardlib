---@diagnostic disable: undefined-doc-name

-- playerctl wrapper module
--
-- Thin wrappers around `playerctl` that construct CLI invocations and return
-- `ward.process.cmd(...)` objects.

local _cmd = require("ward.process")
local args_util = require("wardlib.util.args")
local ensure = require("wardlib.tools.ensure")

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

---@param args string[]
---@param opts PlayerctlOpts|nil
local function apply_opts(args, opts)
	opts = opts or {}

	args_util
		.parser(args, opts)
		:value_token("player", "--player", "player")
		:flag("all_players", "--all-players")
		:repeatable("ignore", "--ignore-player", {
			label = "ignore",
			validate = function(v, l) args_util.token(v, l) end,
		})
		:extra()
end

---@param subcmd string
---@param argv string[]|nil
---@param opts PlayerctlOpts|nil
---@return ward.Cmd
function Playerctl.cmd(subcmd, argv, opts)
	ensure.bin(Playerctl.bin, { label = "playerctl binary" })
	args_util.token(subcmd, "subcmd")
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

function Playerctl.play(opts) return Playerctl.cmd("play", nil, opts) end

function Playerctl.pause(opts) return Playerctl.cmd("pause", nil, opts) end

function Playerctl.play_pause(opts) return Playerctl.cmd("play-pause", nil, opts) end

function Playerctl.next(opts) return Playerctl.cmd("next", nil, opts) end

function Playerctl.previous(opts) return Playerctl.cmd("previous", nil, opts) end

function Playerctl.stop(opts) return Playerctl.cmd("stop", nil, opts) end

function Playerctl.status(opts) return Playerctl.cmd("status", nil, opts) end

---`playerctl metadata [--format <fmt>]`
---@param opts PlayerctlMetadataOpts|nil
---@return ward.Cmd
function Playerctl.metadata(opts)
	opts = opts or {}
	local local_argv = {}
	args_util.parser(local_argv, opts):value_string("format", "--format", "format")
	-- place format before subcommand by using opts.extra? playerctl allows global options
	-- but `--format` is specific to metadata; we append after subcmd per playerctl syntax.
	return Playerctl.cmd("metadata", local_argv, opts)
end

return {
	Playerctl = Playerctl,
}
