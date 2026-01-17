---@diagnostic disable: undefined-doc-name

-- swaybg wrapper module
--
-- Thin wrappers around `swaybg` (Wayland background helper for sway/wlroots)
-- that construct CLI invocations and return `ward.process.cmd(...)` objects.
--
-- This module intentionally does not parse output.

local _cmd = require("ward.process")
local args_util = require("wardlib.util.args")
local ensure = require("wardlib.tools.ensure")
local validate = require("wardlib.util.validate")

---@alias SwaybgMode "stretch"|"fill"|"fit"|"center"|"tile"

---@class SwaybgOutput
---@field name string? Output name (e.g. "DP-1")
---@field image string Path to image
---@field mode SwaybgMode? Output mode
---@field color string? Background color (hex or name) when no image or for gaps

---@class SwaybgOpts
---@field outputs SwaybgOutput|SwaybgOutput[]? One or more output specs. Each produces `-o/-i/-m/-c` flags.
---@field extra string[]? Extra args appended after modeled options

---@class Swaybg
---@field bin string Executable name or path to `swaybg`
---@field set fun(image: string, mode: SwaybgMode|nil, color: string|nil): ward.Cmd Convenience: single output
---@field run fun(opts: SwaybgOpts): ward.Cmd Full control
local Swaybg = {
	bin = "swaybg",
}

---@param mode string
local function validate_mode(mode)
	local ok = {
		stretch = true,
		fill = true,
		fit = true,
		center = true,
		tile = true,
	}
	assert(ok[mode] == true, "invalid mode: " .. tostring(mode))
end

---@param out SwaybgOutput
---@param args string[]
local function apply_output(out, args)
	assert(type(out) == "table", "output must be a table")
	validate.non_empty_string(out.image, "image")

	-- preserve option ordering: -o, -i, -m, -c
	local p = args_util.parser(args, out)
	p:value_string("name", "-o", "name")
	p:value_string("image", "-i", "image")
	p:value("mode", "-m", {
		label = "mode",
		validate = function(v, l)
			validate.non_empty_string(v, l)
			validate_mode(v)
		end,
	})
	p:value_string("color", "-c", "color")
end

---@param args string[]
---@param opts SwaybgOpts
local function apply_opts(args, opts)
	assert(type(opts) == "table", "opts is required")

	if opts.outputs ~= nil then
		local outs = {}
		if type(opts.outputs) == "table" and opts.outputs.image ~= nil then
			outs = { opts.outputs }
		elseif type(opts.outputs) == "table" then
			outs = opts.outputs
		else
			error("outputs must be SwaybgOutput or SwaybgOutput[]")
		end
		assert(#outs > 0, "outputs list must be non-empty")
		for _, o in ipairs(outs) do
			apply_output(o, args)
		end
	else
		error("opts.outputs is required")
	end

	args_util.parser(args, opts):extra()
end

---Convenience: set wallpaper for default output.
---@param image string
---@param mode SwaybgMode|nil
---@param color string|nil
---@return ward.Cmd
function Swaybg.set(image, mode, color)
	ensure.bin(Swaybg.bin, { label = "swaybg binary" })
	validate.non_empty_string(image, "image")
	local out = { image = image }
	if mode ~= nil then
		validate.non_empty_string(mode, "mode")
		validate_mode(mode)
		out.mode = mode
	end
	if color ~= nil then
		validate.non_empty_string(color, "color")
		out.color = color
	end
	return Swaybg.run({ outputs = out })
end

---Full control; specify one or more outputs.
---@param opts SwaybgOpts
---@return ward.Cmd
function Swaybg.run(opts)
	ensure.bin(Swaybg.bin, { label = "swaybg binary" })
	local args = { Swaybg.bin }
	apply_opts(args, opts)
	return _cmd.cmd(table.unpack(args))
end

return {
	Swaybg = Swaybg,
}
