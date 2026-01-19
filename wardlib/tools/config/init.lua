-- wardlib.tools.config
--
-- Format-aware configuration IO built on Ward core codecs (ward.convert.*).
--
-- This module intentionally does NOT attempt to be a full configuration
-- framework. It focuses on the repetitive scripting workflow:
--
--  * infer codec by filename extension
--  * read/write a Lua table
--  * patch in-place
--  * merge helpers (shallow/deep) via ward.helpers.table

local validate = require("wardlib.util.validate")

local fs = require("ward.fs")
local str = require("ward.helpers.string")
local tbl = require("ward.helpers.table")

local M = {}

local FORMAT_BY_EXT = {
	json = "json",
	yaml = "yaml",
	yml = "yaml",
	toml = "toml",
	ini = "ini",
}

local function lower(s) return string.lower(tostring(s)) end

local function extname(path)
	local p = tostring(path)
	-- Normalize Windows separators so extension detection works cross-platform.
	p = p:gsub("\\\\", "/")
	local ext = p:match("%.([^./]+)$")
	if not ext then return nil end
	return lower(ext)
end

local function load_codec(fmt)
	fmt = lower(fmt)
	if fmt == "json" then return require("ward.convert.json") end
	if fmt == "yaml" then return require("ward.convert.yaml") end
	if fmt == "toml" then return require("ward.convert.toml") end
	if fmt == "ini" then return require("ward.convert.ini") end
	error("tools.config: unsupported format: " .. tostring(fmt), 3)
end

-- Infer codec format from the path extension.
-- Returns one of: json|yaml|toml|ini or nil if not recognized.
-- @param path string
function M.infer_format(path)
	validate.non_empty_string(path, "path")
	local ext = extname(path)
	if not ext then return nil end
	return FORMAT_BY_EXT[ext]
end

local function ensure_parent_dir(path)
	local dir = fs.dirname(path)
	if dir == nil or dir == "" or dir == "." then return end
	if fs.is_dir(dir) then return end
	local r = fs.mkdir(dir, { recursive = true })
	if not r.ok then error("tools.config: failed to create directory: " .. tostring(r.err), 3) end
end

local function normalize_text(text, opts)
	opts = opts or {}
	if opts.eof_newline == false then return text end
	if text == "" then return "\n" end
	if not str.ends_with(text, "\n") then return text .. "\n" end
	return text
end

-- Read config file and decode to a Lua value.
-- @param path string
-- @param opts table|nil
function M.read(path, opts)
	validate.non_empty_string(path, "path")
	opts = opts or {}

	local fmt = opts.format or M.infer_format(path)
	if not fmt then error("tools.config.read: cannot infer format for: " .. path, 2) end
	if not fs.is_exists(path) then error("tools.config.read: file does not exist: " .. path, 2) end

	local text = fs.read(path, { mode = "text" })
	local codec = load_codec(fmt)
	return codec.decode(text)
end

-- Write config file.
-- Returns true if written, false if skipped due to write_if_changed.
-- @param path string
-- @param value any
-- @param opts table|nil
function M.write(path, value, opts)
	validate.non_empty_string(path, "path")
	opts = opts or {}

	local fmt = opts.format or M.infer_format(path)
	if not fmt then error("tools.config.write: cannot infer format for: " .. path, 2) end

	local codec = load_codec(fmt)
	local text
	if fmt == "json" then
		text = codec.encode(value, { pretty = opts.pretty == true, indent = opts.indent })
	else
		text = codec.encode(value)
	end

	text = normalize_text(text, opts)

	if opts.mkdir == true then ensure_parent_dir(path) end

	if opts.write_if_changed == true and fs.is_exists(path) then
		local old = fs.read(path, { mode = "text" })
		if old == text then return false end
	end

	local r = fs.write(path, text, { mode = "overwrite" })
	if not r.ok then error("tools.config.write: " .. tostring(r.err), 2) end
	return true
end

-- Patch config file in-place.
-- fn(doc) may mutate doc and return nil, or return a replacement table.
-- Returns the final doc.
-- @param path string
-- @param fn function
-- @param opts table|nil
function M.patch(path, fn, opts)
	validate.non_empty_string(path, "path")
	assert(type(fn) == "function", "patch fn must be a function")
	opts = opts or {}

	local allow_missing = opts.allow_missing ~= false

	local doc
	if fs.is_exists(path) then
		doc = M.read(path, opts)
	else
		if not allow_missing then error("tools.config.patch: file does not exist: " .. path, 2) end
		doc = opts.default or {}
	end

	local out = fn(doc)
	if out ~= nil then doc = out end

	local wopts = {}
	for k, v in pairs(opts) do
		wopts[k] = v
	end
	if wopts.write_if_changed == nil then wopts.write_if_changed = true end

	M.write(path, doc, wopts)
	return doc
end

-- Merge two tables.
-- opts.mode = "deep" (default) or "shallow".
function M.merge(base, overlay, opts)
	opts = opts or {}
	local mode = opts.mode or "deep"
	if mode == "deep" then return tbl.deep_merge(base, overlay) end
	if mode == "shallow" then return tbl.merge(base, overlay) end
	error("tools.config.merge: invalid mode: " .. tostring(mode), 2)
end

return M
