---@diagnostic disable: undefined-doc-name

local _cmd = require("ward.process")
local args_util = require("wardlib.util.args")
local ensure = require("wardlib.tools.ensure")
local validate = require("wardlib.util.validate")

local URGENCY_MAP = { low = true, normal = true, critical = true }

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

return {
	Dunst = Dunst,
	DunstifyOptions = DunstifyOptions,
}
