---@diagnostic disable: undefined-doc-name

-- clipboard wrapper module (Wayland)
--
-- Thin wrappers around `wl-copy` and `wl-paste` that construct CLI invocations
-- and return `ward.process.cmd(...)` objects.
--
-- Note: `wl-copy` reads data from stdin. This module only constructs the
-- command; feeding stdin is the caller's responsibility.

local _cmd = require("ward.process")
local _env = require("ward.env")
local _fs = require("ward.fs")

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
	validate_bin(Clipboard.wl_copy_bin, "wl-copy")
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
	if opts.extra ~= nil then
		assert(type(opts.extra) == "table", "extra must be an array of strings")
		for _, v in ipairs(opts.extra) do
			table.insert(args, tostring(v))
		end
	end
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
	validate_bin(Clipboard.wl_paste_bin, "wl-paste")
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
	if opts.extra ~= nil then
		assert(type(opts.extra) == "table", "extra must be an array of strings")
		for _, v in ipairs(opts.extra) do
			table.insert(args, tostring(v))
		end
	end
	return _cmd.cmd(table.unpack(args))
end

return {
	Clipboard = Clipboard,
}
