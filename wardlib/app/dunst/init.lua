---@diagnostic disable: undefined-doc-name

local _cmd = require("ward.process")
local args_util = require("wardlib.util.args")
local ensure = require("wardlib.tools.ensure")
local validate = require("wardlib.util.validate")

local URGENCY_MAP = { low = true, normal = true, critical = true }

local COUNT_SCOPE_MAP = { displayed = true, history = true, waiting = true }
local BOOL_TOGGLE_MAP = { ["true"] = true, ["false"] = true, toggle = true }
local RULE_ACTION_MAP = { enable = true, disable = true, toggle = true }

---@class DunstifyOptions
---@field body string?
---@field app_name string?
---@field urgency "low"|"normal"|"critical"?
---@field timeout integer?
---@field hints string?
---@field action string?
---@field icon string?
---@field raw_icon string?
---@field category string?
---@field replaceId number|string?
---@field block boolean?
---@field printId boolean?
local DunstifyOptions = {
	body = nil,
	app_name = nil,
	urgency = nil,
	timeout = nil,
	hints = nil,
	action = nil,
	icon = nil,
	raw_icon = nil,
	category = nil,
	replaceId = nil,
	block = false,
	printId = false,
}

---@class Dunst
---@field bin string Executable name or path
---@field notify fun(summary: string, opts: DunstifyOptions): Cmd
---@field close fun(id: integer): Cmd
---@field capabilities fun(): Cmd
---@field serverInfo fun(): Cmd
local Dunst = {
	bin = "dunstify",
}

---@class DunstCtl
---@field bin string Executable name or path
---@field close fun(): Cmd
---@field closeAll fun(): Cmd
---@field context fun(): Cmd
---@field historyPop fun(id?: number|string): Cmd
---@field historyRm fun(id: number|string): Cmd
---@field historyClear fun(): Cmd
---@field isPaused fun(): Cmd
---@field setPaused fun(v: boolean|"true"|"false"|"toggle"): Cmd
---@field getPauseLevel fun(): Cmd
---@field setPauseLevel fun(level: integer): Cmd
---@field count fun(scope?: "displayed"|"history"|"waiting"): Cmd
---@field action fun(notification_position: integer): Cmd
---@field rule fun(rule_name: string, action: "enable"|"disable"|"toggle"): Cmd
---@field rules fun(opts?: { json: boolean? }): Cmd
---@field reload fun(files?: string|string[]): Cmd
---@field debug fun(): Cmd
---@field help fun(): Cmd
local DunstCtl = {
	bin = "dunstctl",
}

---Send notification
---@param summary string
---@param opts DunstifyOptions?
---@return ward.Cmd
function Dunst.notify(summary, opts)
	opts = opts or {}
	local args = { Dunst.bin }
	ensure.bin(Dunst.bin, { label = "Dunstify binary" })
	assert(type(summary) == "string" and #summary > 0, "summary must be a non-empty string")

	local eff = {
		app_name = opts.app_name or DunstifyOptions.app_name,
		replaceId = opts.replaceId or DunstifyOptions.replaceId,
		urgency = opts.urgency or DunstifyOptions.urgency,
		timeout = opts.timeout or DunstifyOptions.timeout,
		hints = opts.hints or DunstifyOptions.hints,
		action = opts.action or DunstifyOptions.action,
		icon = opts.icon or DunstifyOptions.icon,
		raw_icon = opts.raw_icon or DunstifyOptions.raw_icon,
		category = opts.category or DunstifyOptions.category,
		block = opts.block or DunstifyOptions.block,
		printId = opts.printId or DunstifyOptions.printId,
	}

	args_util
		.parser(args, eff)
		:value("app_name", "-a", {
			validate = function(v, l) validate.non_empty_string(v, l) end,
		})
		:value("urgency", "-u", {
			validate = function(v, l)
				validate.non_empty_string(v, l)
				assert(URGENCY_MAP[v], "Unknown urgency: " .. tostring(v))
			end,
		})
		:value("timeout", "-t", {
			validate = function(v, l)
				assert(type(v) == "number" or type(v) == "string", l .. " must be a number or string")
			end,
		})
		:value("hints", "-h", {
			validate = function(v, l) validate.non_empty_string(v, l) end,
		})
		:value("action", "-A", {
			validate = function(v, l) validate.non_empty_string(v, l) end,
		})
		:value("icon", "-i", {
			validate = function(v, l) validate.non_empty_string(v, l) end,
		})
		:value("raw_icon", "-I", {
			validate = function(v, l) validate.non_empty_string(v, l) end,
		})
		:value("category", "-c", {
			validate = function(v, l) validate.non_empty_string(v, l) end,
		})
		:value("replaceId", "-r", {
			validate = function(v, _)
				assert(type(v) == "number" or type(v) == "string", "replaceId must be a number or string")
			end,
		})
		:flag("block", "-b")
		:flag("printId", "-p")

	args[#args + 1] = summary

	local body = opts.body or DunstifyOptions.body
	if body ~= nil then args[#args + 1] = body end

	return _cmd.cmd(table.unpack(args))
end

---Close notification by id
---@param id number|string
---@return ward.Cmd
function Dunst.close(id)
	ensure.bin(Dunst.bin, { label = "Dunstify binary" })
	return _cmd.cmd(Dunst.bin, "-C", tostring(id))
end

---Dunst capabilities
---@return ward.Cmd
function Dunst.capabilities()
	ensure.bin(Dunst.bin, { label = "Dunstify binary" })
	return _cmd.cmd(Dunst.bin, "--capabilities")
end

---Dunst server info
---@return ward.Cmd
function Dunst.serverInfo()
	ensure.bin(Dunst.bin, { label = "Dunstify binary" })
	return _cmd.cmd(Dunst.bin, "--serverinfo")
end

local function normalize_bool_toggle(v)
	if type(v) == "boolean" then return v and "true" or "false" end
	validate.non_empty_string(v, "setPaused")
	v = tostring(v):lower()
	assert(BOOL_TOGGLE_MAP[v], "setPaused must be true, false, or toggle")
	return v
end

local function validate_pause_level(level)
	assert(type(level) == "number" or type(level) == "string", "pause level must be a number or string")
	local n = tonumber(level)
	assert(n ~= nil, "pause level must be numeric")
	assert(n >= 0 and n <= 100, "pause level must be in range 0..100")
	return tostring(math.floor(n))
end

---Close the topmost notification currently being displayed.
---@return ward.Cmd
function DunstCtl.close()
	ensure.bin(DunstCtl.bin, { label = "dunstctl binary" })
	return _cmd.cmd(DunstCtl.bin, "close")
end

---Close all notifications currently being displayed.
---@return ward.Cmd
function DunstCtl.closeAll()
	ensure.bin(DunstCtl.bin, { label = "dunstctl binary" })
	return _cmd.cmd(DunstCtl.bin, "close-all")
end

---Open the context menu.
---@return ward.Cmd
function DunstCtl.context()
	ensure.bin(DunstCtl.bin, { label = "dunstctl binary" })
	return _cmd.cmd(DunstCtl.bin, "context")
end

---Redisplay the notification that was most recently closed (optionally by id).
---@param id number|string|nil
---@return ward.Cmd
function DunstCtl.historyPop(id)
	ensure.bin(DunstCtl.bin, { label = "dunstctl binary" })
	if id == nil then return _cmd.cmd(DunstCtl.bin, "history-pop") end
	assert(type(id) == "number" or type(id) == "string", "historyPop id must be a number or string")
	return _cmd.cmd(DunstCtl.bin, "history-pop", tostring(id))
end

---Remove a notification from history.
---@param id number|string
---@return ward.Cmd
function DunstCtl.historyRm(id)
	ensure.bin(DunstCtl.bin, { label = "dunstctl binary" })
	assert(type(id) == "number" or type(id) == "string", "historyRm id must be a number or string")
	return _cmd.cmd(DunstCtl.bin, "history-rm", tostring(id))
end

---Clear all notifications from history.
---@return ward.Cmd
function DunstCtl.historyClear()
	ensure.bin(DunstCtl.bin, { label = "dunstctl binary" })
	return _cmd.cmd(DunstCtl.bin, "history-clear")
end

---Check whether dunst is paused.
---@return ward.Cmd
function DunstCtl.isPaused()
	ensure.bin(DunstCtl.bin, { label = "dunstctl binary" })
	return _cmd.cmd(DunstCtl.bin, "is-paused")
end

---Set paused status.
---@param v boolean|"true"|"false"|"toggle"
---@return ward.Cmd
function DunstCtl.setPaused(v)
	ensure.bin(DunstCtl.bin, { label = "dunstctl binary" })
	return _cmd.cmd(DunstCtl.bin, "set-paused", normalize_bool_toggle(v))
end

---Get current pause level (0..100).
---@return ward.Cmd
function DunstCtl.getPauseLevel()
	ensure.bin(DunstCtl.bin, { label = "dunstctl binary" })
	return _cmd.cmd(DunstCtl.bin, "get-pause-level")
end

---Set pause level (0..100).
---@param level integer
---@return ward.Cmd
function DunstCtl.setPauseLevel(level)
	ensure.bin(DunstCtl.bin, { label = "dunstctl binary" })
	return _cmd.cmd(DunstCtl.bin, "set-pause-level", validate_pause_level(level))
end

---Show the number of notifications.
---@param scope "displayed"|"history"|"waiting"|nil
---@return ward.Cmd
function DunstCtl.count(scope)
	ensure.bin(DunstCtl.bin, { label = "dunstctl binary" })
	if scope == nil then return _cmd.cmd(DunstCtl.bin, "count") end
	validate.non_empty_string(scope, "count scope")
	scope = tostring(scope):lower()
	assert(COUNT_SCOPE_MAP[scope], "count scope must be displayed, history, or waiting")
	return _cmd.cmd(DunstCtl.bin, "count", scope)
end

---Perform the default action or open context menu for a notification at a given position.
---@param notification_position integer
---@return ward.Cmd
function DunstCtl.action(notification_position)
	ensure.bin(DunstCtl.bin, { label = "dunstctl binary" })
	assert(type(notification_position) == "number", "notification_position must be a number")
	assert(notification_position >= 0, "notification_position must be >= 0")
	return _cmd.cmd(DunstCtl.bin, "action", tostring(math.floor(notification_position)))
end

---Enable/disable/toggle a configured rule by name.
---@param rule_name string
---@param action "enable"|"disable"|"toggle"
---@return ward.Cmd
function DunstCtl.rule(rule_name, action)
	ensure.bin(DunstCtl.bin, { label = "dunstctl binary" })
	validate.non_empty_string(rule_name, "rule name")
	validate.non_empty_string(action, "rule action")
	action = tostring(action):lower()
	assert(RULE_ACTION_MAP[action], "rule action must be enable, disable, or toggle")
	return _cmd.cmd(DunstCtl.bin, "rule", rule_name, action)
end

---Export all configured rules.
---@param opts { json: boolean? }|nil
---@return ward.Cmd
function DunstCtl.rules(opts)
	ensure.bin(DunstCtl.bin, { label = "dunstctl binary" })
	opts = opts or {}
	if opts.json then return _cmd.cmd(DunstCtl.bin, "rules", "--json") end
	return _cmd.cmd(DunstCtl.bin, "rules")
end

---Reload dunst configuration.
---@param files string|string[]|nil
---@return ward.Cmd
function DunstCtl.reload(files)
	ensure.bin(DunstCtl.bin, { label = "dunstctl binary" })
	if files == nil then return _cmd.cmd(DunstCtl.bin, "reload") end
	local list = args_util.normalize_string_or_array(files, "reload files")
	local args = { DunstCtl.bin, "reload" }
	for _, f in ipairs(list) do
		validate.non_empty_string(f, "reload file")
		args[#args + 1] = f
	end
	return _cmd.cmd(table.unpack(args))
end

---Debug dunstctl ↔ dunst connection.
---@return ward.Cmd
function DunstCtl.debug()
	ensure.bin(DunstCtl.bin, { label = "dunstctl binary" })
	return _cmd.cmd(DunstCtl.bin, "debug")
end

---Print dunstctl help.
---@return ward.Cmd
function DunstCtl.help()
	ensure.bin(DunstCtl.bin, { label = "dunstctl binary" })
	return _cmd.cmd(DunstCtl.bin, "help")
end

return {
	Dunst = Dunst,
	DunstCtl = DunstCtl,
	DunstifyOptions = DunstifyOptions,
}
