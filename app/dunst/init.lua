---@diagnostic disable: undefined-doc-name

local _cmd = require("ward.process")
local _env = require("ward.env")
local _fs = require("ward.fs")

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

---Validate binary
---@param bin string
local validate_bin = function(bin)
	assert(type(bin) == "string" and #bin > 0, "Dunstify binary is not set")
	if bin:find("/", 1, true) then
		assert(_fs.is_exists(bin), string.format("Dunstify binary is not exists: %s", bin))
		assert(_fs.is_executable(bin), string.format("Dunstify binary is not executable: %s", bin))
	else
		assert(_env.is_in_path(bin), string.format("Dunstify binary is not in PATH: %s", bin))
	end
end

---Send notification
---@param summary string
---@param opts DunstifyOptions?
---@return ward.Cmd
function Dunst.notify(summary, opts)
	opts = opts or {}
	local args = { Dunst.bin }
	validate_bin(Dunst.bin)
	assert(type(summary) == "string" and #summary > 0, "summary must be a non-empty string")

	local app_name = opts.app_name or DunstifyOptions.app_name
	if app_name ~= nil then
		table.insert(args, "-a")
		table.insert(args, app_name)
	end

	local urgency = opts.urgency or DunstifyOptions.urgency
	if urgency ~= nil then
		assert(URGENCY_MAP[urgency], "Unknown urgency: " .. tostring(urgency))

		table.insert(args, "-u")
		table.insert(args, urgency)
	end

	local timeout = opts.timeout or DunstifyOptions.timeout
	if timeout ~= nil then
		table.insert(args, "-t")
		table.insert(args, tostring(timeout))
	end

	local hints = opts.hints or DunstifyOptions.hints
	if hints ~= nil then
		table.insert(args, "-h")
		table.insert(args, hints)
	end

	local action = opts.action or DunstifyOptions.action
	if action ~= nil then
		table.insert(args, "-A")
		table.insert(args, action)
	end

	local icon = opts.icon or DunstifyOptions.icon
	if icon ~= nil then
		table.insert(args, "-i")
		table.insert(args, icon)
	end

	local raw_icon = opts.raw_icon or DunstifyOptions.raw_icon
	if raw_icon ~= nil then
		table.insert(args, "-I")
		table.insert(args, raw_icon)
	end

	local category = opts.category or DunstifyOptions.category
	if category ~= nil then
		table.insert(args, "-c")
		table.insert(args, category)
	end

	local replaceId = opts.replaceId or DunstifyOptions.replaceId
	if replaceId ~= nil then
		table.insert(args, "-r")
		table.insert(args, tostring(replaceId))
	end

	local block = opts.block or DunstifyOptions.block
	if block then
		table.insert(args, "-b")
	end

	local printId = opts.printId or DunstifyOptions.printId
	if printId then
		table.insert(args, "-p")
	end

	table.insert(args, summary)

	local body = opts.body or DunstifyOptions.body
	if body ~= nil then
		table.insert(args, body)
	end

	return _cmd.cmd(table.unpack(args))
end

---Close notification by id
---@param id number|string
---@return ward.Cmd
function Dunst.close(id)
	validate_bin(Dunst.bin)
	return _cmd.cmd(Dunst.bin, "-C", tostring(id))
end

---Dunst capabilities
---@return ward.Cmd
function Dunst.capabilities()
	validate_bin(Dunst.bin)
	return _cmd.cmd(Dunst.bin, "--capabilities")
end

---Dunst server info
---@return ward.Cmd
function Dunst.serverInfo()
	validate_bin(Dunst.bin)
	return _cmd.cmd(Dunst.bin, "--serverinfo")
end

return {
	Dunst = Dunst,
	DunstifyOptions = DunstifyOptions,
}
