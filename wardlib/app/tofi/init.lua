---@diagnostic disable: undefined-doc-name

-- tofi wrapper module
--
-- Thin wrappers around `tofi`, `tofi-run`, and `tofi-drun`.
--
-- These wrappers focus on common CLI flags; use `extra` for anything else.
-- This module intentionally does not parse output.

local _cmd = require("ward.process")
local args_util = require("wardlib.util.args")
local ensure = require("wardlib.tools.ensure")
local validate = require("wardlib.util.validate")

---@class TofiOpts
---@field config string? `-c <file>`
---@field prompt_text string? `--prompt-text <text>`
---@field num_results number? `--num-results <n>`
---@field require_match boolean? `--require-match`
---@field fuzzy_match boolean? `--fuzzy-match`
---@field width string? `--width <w>`
---@field height string? `--height <h>`
---@field font string? `--font <font>`
---@field defines table<string, any>? Additional `--key <value>` pairs (stable key order).
---@field extra string[]? Extra argv appended after modeled options

---@class Tofi
---@field bin string Executable name or path to `tofi`
---@field bin_run string Executable name or path to `tofi-run`
---@field bin_drun string Executable name or path to `tofi-drun`
---@field menu fun(opts?: TofiOpts): ward.Cmd
---@field run fun(opts?: TofiOpts): ward.Cmd
---@field drun fun(opts?: TofiOpts): ward.Cmd
local Tofi = {
	bin = "tofi",
	bin_run = "tofi-run",
	bin_drun = "tofi-drun",
}

---@param args string[]
---@param opts TofiOpts|nil
local function apply_opts(args, opts)
	opts = opts or {}
	local p = args_util.parser(args, opts)

	p:value_string("config", "-c", "config")
		:value_string("prompt_text", "--prompt-text", "prompt_text")
		:value_number("num_results", "--num-results", { label = "num_results", integer = true, min = 0 })
		:value_string("width", "--width", "width")
		:value_string("height", "--height", "height")
		:value_string("font", "--font", "font")

	p:flag("require_match", "--require-match"):flag("fuzzy_match", "--fuzzy-match")

	-- Arbitrary key/value pairs (stable order).
	if opts.defines ~= nil then
		assert(type(opts.defines) == "table", "defines must be a table")
		for _, k in ipairs(args_util.sorted_keys(opts.defines)) do
			validate.non_empty_string(k, "define key")
			local v = opts.defines[k]
			if v == true then
				args[#args + 1] = "--" .. k
			elseif v == false or v == nil then
				-- skip
			else
				args[#args + 1] = "--" .. k
				args[#args + 1] = tostring(v)
			end
		end
	end

	p:extra("extra")
end

---@param bin string
---@param opts TofiOpts|nil
---@return ward.Cmd
local function run_bin(bin, opts)
	ensure.bin(bin, { label = "tofi binary" })
	local o = args_util.clone_opts(opts, { "extra" })
	local args = { bin }
	apply_opts(args, o)
	return _cmd.cmd(table.unpack(args))
end

---Builds: `tofi <opts...>`
---@param opts TofiOpts|nil
---@return ward.Cmd
function Tofi.menu(opts) return run_bin(Tofi.bin, opts) end

---Builds: `tofi-run <opts...>`
---@param opts TofiOpts|nil
---@return ward.Cmd
function Tofi.run(opts) return run_bin(Tofi.bin_run, opts) end

---Builds: `tofi-drun <opts...>`
---@param opts TofiOpts|nil
---@return ward.Cmd
function Tofi.drun(opts) return run_bin(Tofi.bin_drun, opts) end

return { Tofi = Tofi }