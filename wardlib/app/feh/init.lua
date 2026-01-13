---@diagnostic disable: undefined-doc-name

-- feh wrapper module
--
-- Thin wrappers around `feh` (image viewer / wallpaper setter) that construct
-- CLI invocations and return `ward.process.cmd(...)` objects.
--
-- This module intentionally does not parse output.

local _cmd = require("ward.process")
local validate = require("wardlib.util.validate")
local ensure = require("wardlib.tools.ensure")
local args_util = require("wardlib.util.args")

---@alias FehBgMode "center"|"fill"|"max"|"scale"|"tile"

---@class FehOpts
---@field fullscreen boolean? `-F`
---@field borderless boolean? `-x`
---@field keep_zoom_vp boolean? `--keep-zoom-vp`
---@field zoom number? `-Z` (auto-zoom) or `--zoom <percent>` when using zoom_percent
---@field zoom_percent number? `--zoom <percent>`
---@field auto_rotate boolean? `--auto-rotate`
---@field draw_filename boolean? `-d`
---@field caption_path string? `--caption-path <dir>`
---@field title string? `--title <title>`
---@field geometry string? `-g <WxH+X+Y>`
---@field reload number? `--reload <sec>`
---@field slideshow_delay number? `-D <sec>`
---@field recursive boolean? `-r`
---@field sort string? `--sort <mode>`
---@field reverse boolean? `--reverse`
---@field randomize boolean? `--randomize`
---@field preload boolean? `--preload`
---@field cache_size number? `--cache-size <MB>`
---@field extra string[]? Extra args appended after modeled options

---@class FehBgOpts
---@field mode FehBgMode? Background mode (maps to --bg-*)
---@field no_fehbg boolean? Do not write ~/.fehbg (`--no-fehbg`)
---@field extra string[]? Extra args appended after modeled options

---@class Feh
---@field bin string Executable name or path to `feh`
---@field view fun(inputs: string|string[]|nil, opts: FehOpts|nil): ward.Cmd
---@field bg fun(image: string, opts: FehBgOpts|nil): ward.Cmd Set wallpaper using feh
---@field bg_multi fun(images: string|string[], opts: FehBgOpts|nil): ward.Cmd Set wallpaper using multiple images
local Feh = {
	bin = "feh",
}

---@param args string[]
---@param opts FehOpts|nil
local function apply_view_opts(args, opts)
	opts = opts or {}

	-- preserve original ordering
	local p = args_util.parser(args, opts)
	p:flag("fullscreen", "-F")
		:flag("borderless", "-x")
		:flag("keep_zoom_vp", "--keep-zoom-vp")
		:flag("auto_rotate", "--auto-rotate")
		:flag("draw_filename", "-d")
		:flag("recursive", "-r")
		:flag("reverse", "--reverse")
		:flag("randomize", "--randomize")
		:flag("preload", "--preload")

	p:value_string("title", "--title", "title")
		:value_string("caption_path", "--caption-path", "caption_path")
		:value_string("geometry", "-g", "geometry")
		:value_number("reload", "--reload", { non_negative = true, label = "reload" })
		:value_number("slideshow_delay", "-D", { non_negative = true, label = "slideshow_delay" })
		:value_string("sort", "--sort", "sort")
		:value_number("cache_size", "--cache-size", { non_negative = true, label = "cache_size" })

	-- zoom: feh has -Z for auto-zoom, and --zoom <percent>.
	p:flag("zoom", "-Z")
	p:value("zoom_percent", "--zoom", {
		label = "zoom_percent",
		validate = function(v, l)
			assert(type(v) == "number" and v >= 0, l .. " must be a non-negative number")
			assert(v > 0, "zoom_percent must be > 0")
		end,
	})

	p:extra()
end

---@param args string[]
---@param inputs string|string[]|nil
local function apply_inputs(args, inputs)
	if inputs == nil then
		return
	end
	local list = args_util.normalize_string_or_array(inputs, "inputs")
	assert(#list > 0, "inputs list must be non-empty")
	for _, p in ipairs(list) do
		validate.non_empty_string(p, "input")
		table.insert(args, p)
	end
end

---@param args string[]
---@param opts FehBgOpts|nil
local function apply_bg_opts(args, opts)
	opts = opts or {}
	local mode = opts.mode
	if mode ~= nil then
		assert(type(mode) == "string", "mode must be a string")
		local map = {
			center = "--bg-center",
			fill = "--bg-fill",
			max = "--bg-max",
			scale = "--bg-scale",
			tile = "--bg-tile",
		}
		local flag = map[mode]
		assert(flag ~= nil, "unknown bg mode: " .. tostring(mode))
		table.insert(args, flag)
	end

	args_util.parser(args, opts):flag("no_fehbg", "--no-fehbg"):extra()
end

---Construct a feh viewing command.
---
---If `inputs` is nil, feh will run with only the configured options.
---@param inputs string|string[]|nil
---@param opts FehOpts|nil
---@return ward.Cmd
function Feh.view(inputs, opts)
	ensure.bin(Feh.bin, { label = "feh binary" })
	local args = { Feh.bin }
	apply_view_opts(args, opts)
	apply_inputs(args, inputs)
	return _cmd.cmd(table.unpack(args))
end

---Set wallpaper using a single image.
---@param image string
---@param opts FehBgOpts|nil
---@return ward.Cmd
function Feh.bg(image, opts)
	ensure.bin(Feh.bin, { label = "feh binary" })
	validate.non_empty_string(image, "image")
	local args = { Feh.bin }
	apply_bg_opts(args, opts)
	table.insert(args, image)
	return _cmd.cmd(table.unpack(args))
end

---Set wallpaper using multiple images.
---@param images string|string[]
---@param opts FehBgOpts|nil
---@return ward.Cmd
function Feh.bg_multi(images, opts)
	ensure.bin(Feh.bin, { label = "feh binary" })
	local args = { Feh.bin }
	apply_bg_opts(args, opts)
	apply_inputs(args, images)
	return _cmd.cmd(table.unpack(args))
end

return {
	Feh = Feh,
}
