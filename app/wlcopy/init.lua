---@diagnostic disable: undefined-doc-name

-- clipboard wrapper module (Wayland)
--
-- Thin wrappers around `wl-copy` and `wl-paste` that construct CLI invocations
-- and return `ward.process.cmd(...)` objects.
--
-- Note: `wl-copy` reads data from stdin. This module only constructs the
-- command; feeding stdin is the caller's responsibility.

local _cmd = require("ward.process")
local validate = require("util.validate")
local ensure = require("tools.ensure")
local args_util = require("util.args")

---@class ClipboardSelectionOpts
---@field selection "clipboard"|"primary"|nil

---@class ClipboardCopyOpts: ClipboardSelectionOpts
---@field type string? MIME type (`--type <mime>`)
---@field foreground boolean? `--foreground`
---@field paste_once boolean? `--paste-once`
---@field clear boolean? `--clear`
---@field extra string[]? Extra args appended

---@class ClipboardPasteOpts: ClipboardSelectionOpts
---@field type string? MIME type (`--type <mime>`)
---@field no_newline boolean? `--no-newline`
---@field extra string[]? Extra args appended

---@class Clipboard
---@field wl_copy_bin string
---@field wl_paste_bin string
---@field copy fun(opts: ClipboardCopyOpts|nil): ward.Cmd
---@field clear fun(opts: ClipboardSelectionOpts|nil): ward.Cmd
---@field paste fun(opts: ClipboardPasteOpts|nil): ward.Cmd
local Clipboard = {
	wl_copy_bin = "wl-copy",
	wl_paste_bin = "wl-paste",
}

---@param args string[]
---@param selection "clipboard"|"primary"|nil
local function apply_selection(args, selection)
	if selection == nil or selection == "clipboard" then
		return
	end
	if selection == "primary" then
		table.insert(args, "--primary")
		return
	end
	error("unsupported selection: " .. tostring(selection))
end

---Construct wl-copy invocation.
---@param opts ClipboardCopyOpts|nil
---@return ward.Cmd
function Clipboard.copy(opts)
	ensure.bin(Clipboard.wl_copy_bin, { label = "wl-copy binary" })
	opts = opts or {}
	local args = { Clipboard.wl_copy_bin }
	apply_selection(args, opts.selection)

	if opts.type ~= nil then
		assert(type(opts.type) == "string" and #opts.type > 0, "type must be a non-empty string")
		table.insert(args, "--type")
		table.insert(args, opts.type)
	end
	if opts.foreground then
		table.insert(args, "--foreground")
	end
	if opts.paste_once then
		table.insert(args, "--paste-once")
	end
	if opts.clear then
		table.insert(args, "--clear")
	end
	args_util.append_extra(args, opts.extra)
	return _cmd.cmd(table.unpack(args))
end

---Clear clipboard selection.
---@param opts ClipboardSelectionOpts|nil
---@return ward.Cmd
function Clipboard.clear(opts)
	opts = opts or {}
	return Clipboard.copy({
		selection = opts.selection,
		clear = true,
	})
end

---Construct wl-paste invocation.
---@param opts ClipboardPasteOpts|nil
---@return ward.Cmd
function Clipboard.paste(opts)
	ensure.bin(Clipboard.wl_paste_bin, { label = "wl-paste binary" })
	opts = opts or {}
	local args = { Clipboard.wl_paste_bin }
	apply_selection(args, opts.selection)

	if opts.type ~= nil then
		assert(type(opts.type) == "string" and #opts.type > 0, "type must be a non-empty string")
		table.insert(args, "--type")
		table.insert(args, opts.type)
	end
	if opts.no_newline then
		table.insert(args, "--no-newline")
	end
	args_util.append_extra(args, opts.extra)
	return _cmd.cmd(table.unpack(args))
end

return {
	Clipboard = Clipboard,
}
