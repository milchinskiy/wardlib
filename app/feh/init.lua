---@diagnostic disable: undefined-doc-name

-- feh wrapper module
--
-- Thin wrappers around `feh` (image viewer / wallpaper setter) that construct
-- CLI invocations and return `ward.process.cmd(...)` objects.
--
-- This module intentionally does not parse output.

local _cmd = require("ward.process")
local validate = require("util.validate")
local ensure = require("tools.ensure")
local args_util = require("util.args")

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

---@param v any
---@param label string
local function validate_number(v, label)
	assert(type(v) == "number" and v >= 0, label .. " must be a non-negative number")
end

---@param args string[]
---@param opts FehOpts|nil
local function apply_view_opts(args, opts)
	opts = opts or {}

	if opts.fullscreen then
		table.insert(args, "-F")
	end
	if opts.borderless then
		table.insert(args, "-x")
	end
	if opts.keep_zoom_vp then
		table.insert(args, "--keep-zoom-vp")
	end
	if opts.auto_rotate then
		table.insert(args, "--auto-rotate")
	end
	if opts.draw_filename then
		table.insert(args, "-d")
	end
	if opts.recursive then
		table.insert(args, "-r")
	end
	if opts.reverse then
		table.insert(args, "--reverse")
	end
	if opts.randomize then
		table.insert(args, "--randomize")
	end
	if opts.preload then
		table.insert(args, "--preload")
	end

	if opts.title ~= nil then
		validate.non_empty_string(opts.title, "title")
		table.insert(args, "--title")
		table.insert(args, opts.title)
	end
	if opts.caption_path ~= nil then
		validate.non_empty_string(opts.caption_path, "caption_path")
		table.insert(args, "--caption-path")
		table.insert(args, opts.caption_path)
	end
	if opts.geometry ~= nil then
		validate.non_empty_string(opts.geometry, "geometry")
		table.insert(args, "-g")
		table.insert(args, opts.geometry)
	end
	if opts.reload ~= nil then
		validate_number(opts.reload, "reload")
		table.insert(args, "--reload")
		table.insert(args, tostring(opts.reload))
	end
	if opts.slideshow_delay ~= nil then
		validate_number(opts.slideshow_delay, "slideshow_delay")
		table.insert(args, "-D")
		table.insert(args, tostring(opts.slideshow_delay))
	end
	if opts.sort ~= nil then
		validate.non_empty_string(opts.sort, "sort")
		table.insert(args, "--sort")
		table.insert(args, opts.sort)
	end
	if opts.cache_size ~= nil then
		validate_number(opts.cache_size, "cache_size")
		table.insert(args, "--cache-size")
		table.insert(args, tostring(opts.cache_size))
	end

	-- zoom: feh has -Z for auto-zoom, and --zoom <percent>.
	-- Here we model --zoom as zoom_percent.
	if opts.zoom then
		table.insert(args, "-Z")
	end
	if opts.zoom_percent ~= nil then
		validate_number(opts.zoom_percent, "zoom_percent")
		assert(opts.zoom_percent > 0, "zoom_percent must be > 0")
		table.insert(args, "--zoom")
		table.insert(args, tostring(opts.zoom_percent))
	end

	args_util.append_extra(args, opts.extra)
end

---@param args string[]
---@param inputs string|string[]|nil
local function apply_inputs(args, inputs)
	if inputs == nil then
		return
	end
	if type(inputs) == "string" then
		validate.non_empty_string(inputs, "input")
		table.insert(args, inputs)
		return
	end
	if type(inputs) == "table" then
		assert(#inputs > 0, "inputs list must be non-empty")
		for _, p in ipairs(inputs) do
			validate.non_empty_string(p, "input")
			table.insert(args, p)
		end
		return
	end
	error("inputs must be string, string[], or nil")
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
	if opts.no_fehbg then
		table.insert(args, "--no-fehbg")
	end
	args_util.append_extra(args, opts.extra)
end

---Construct a feh viewing command.
---
---If `inputs` is nil, feh will run with only the configured options.
---@param inputs string|string[]|nil
---@param opts FehOpts|nil
---@return ward.Cmd
function Feh.view(inputs, opts)
	ensure.bin(Feh.bin, { label = 'feh binary' })
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
	ensure.bin(Feh.bin, { label = 'feh binary' })
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
	ensure.bin(Feh.bin, { label = 'feh binary' })
	local args = { Feh.bin }
	apply_bg_opts(args, opts)
	apply_inputs(args, images)
	return _cmd.cmd(table.unpack(args))
end

return {
	Feh = Feh,
}
