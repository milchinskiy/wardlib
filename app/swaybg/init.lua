---@diagnostic disable: undefined-doc-name

-- swaybg wrapper module
--
-- Thin wrappers around `swaybg` (Wayland background helper for sway/wlroots)
-- that construct CLI invocations and return `ward.process.cmd(...)` objects.
--
-- This module intentionally does not parse output.

local _cmd = require("ward.process")
local _env = require("ward.env")
local _fs = require("ward.fs")

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

---@param bin string
local function validate_bin(bin)
	assert(type(bin) == "string" and #bin > 0, "swaybg binary is not set")
	if bin:find("/", 1, true) then
		assert(_fs.is_exists(bin), string.format("swaybg binary does not exist: %s", bin))
		assert(_fs.is_executable(bin), string.format("swaybg binary is not executable: %s", bin))
	else
		assert(_env.is_in_path(bin), string.format("swaybg binary is not in PATH: %s", bin))
	end
end

---@param s any
---@param label string
local function validate_non_empty_string(s, label)
	assert(type(s) == "string" and #s > 0, label .. " must be a non-empty string")
end

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
	validate_non_empty_string(out.image, "image")

	if out.name ~= nil then
		validate_non_empty_string(out.name, "name")
		table.insert(args, "-o")
		table.insert(args, out.name)
	end

	table.insert(args, "-i")
	table.insert(args, out.image)

	if out.mode ~= nil then
		validate_non_empty_string(out.mode, "mode")
		validate_mode(out.mode)
		table.insert(args, "-m")
		table.insert(args, out.mode)
	end

	if out.color ~= nil then
		validate_non_empty_string(out.color, "color")
		table.insert(args, "-c")
		table.insert(args, out.color)
	end
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

	if opts.extra ~= nil then
		assert(type(opts.extra) == "table", "extra must be an array")
		for _, v in ipairs(opts.extra) do
			table.insert(args, tostring(v))
		end
	end
end

---Convenience: set wallpaper for default output.
---@param image string
---@param mode SwaybgMode|nil
---@param color string|nil
---@return ward.Cmd
function Swaybg.set(image, mode, color)
	validate_bin(Swaybg.bin)
	validate_non_empty_string(image, "image")
	local out = { image = image }
	if mode ~= nil then
		validate_non_empty_string(mode, "mode")
		validate_mode(mode)
		out.mode = mode
	end
	if color ~= nil then
		validate_non_empty_string(color, "color")
		out.color = color
	end
	return Swaybg.run({ outputs = out })
end

---Full control; specify one or more outputs.
---@param opts SwaybgOpts
---@return ward.Cmd
function Swaybg.run(opts)
	validate_bin(Swaybg.bin)
	local args = { Swaybg.bin }
	apply_opts(args, opts)
	return _cmd.cmd(table.unpack(args))
end

return {
	Swaybg = Swaybg,
}
