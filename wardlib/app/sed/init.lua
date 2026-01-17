---@diagnostic disable: undefined-doc-name

-- sed wrapper module
--
-- Thin wrappers around GNU/BSD `sed` that construct CLI invocations and return
-- `ward.process.cmd(...)` objects.
--
-- Notes:
-- * `-E` (extended regex) is supported on both GNU and BSD sed.
-- * `-i` (in-place) differs: BSD sed requires an argument (backup suffix),
--   GNU sed accepts optional suffix. This wrapper models `in_place` as:
--     - boolean true  => pass `-i` (GNU-style)
--     - string suffix => pass `-i<suffix>` (GNU) or `-i <suffix>` (BSD). We use
--        the GNU concatenated form `-i<suffix>` which GNU supports and BSD also
--        accepts for common suffixes.
--   If you need stricter portability, set `extra` explicitly.

local _cmd = require("ward.process")
local args_util = require("wardlib.util.args")
local ensure = require("wardlib.tools.ensure")
local tbl = require("wardlib.util.table")
local validate = require("wardlib.util.validate")

---@class SedOpts
---@field extended boolean? `-E` (extended regex)
---@field quiet boolean? `-n`
---@field in_place boolean|string? `-i` or `-i<suffix>`
---@field backup_suffix string? Convenience alias for `in_place = ".bak"` etc
---@field expression string|string[]? `-e <script>` repeated
---@field file string|string[]? `-f <file>` repeated
---@field null_data boolean? `-z` (GNU) treat input as NUL-separated
---@field follow_symlinks boolean? `--follow-symlinks` (GNU)
---@field posix boolean? `--posix` (GNU)
---@field sandbox boolean? `--sandbox` (GNU)
---@field extra string[]? Extra args appended after modeled options

---@class Sed
---@field bin string Executable name or path to `sed`
---@field run fun(inputs: string|string[]|nil, opts: SedOpts|nil): ward.Cmd
---@field script fun(script: string, inputs: string|string[]|nil, opts: SedOpts|nil): ward.Cmd Convenience: adds `-e <script>`
---@field replace fun(pattern: string, repl: string, inputs: string|string[]|nil, opts: SedOpts|nil): ward.Cmd Convenience: adds `-e s/pattern/repl/g`
---@field inplace_replace fun(pattern: string, repl: string, inputs: string|string[], backup_suffix: string|nil, opts: SedOpts|nil): ward.Cmd Convenience: sets `-i` and adds substitution
local Sed = {
	bin = "sed",
}

---@param args string[]
---@param opts SedOpts|nil
local function apply_opts(args, opts)
	opts = opts or {}

	args_util
		.parser(args, opts)
		:flag("extended", "-E")
		:flag("quiet", "-n")
		:flag("null_data", "-z")
		:flag("follow_symlinks", "--follow-symlinks")
		:flag("posix", "--posix")
		:flag("sandbox", "--sandbox")

	-- in-place handling
	local in_place = opts.in_place
	if opts.backup_suffix ~= nil then
		validate.non_empty_string(opts.backup_suffix, "backup_suffix")
		in_place = opts.backup_suffix
	end
	if in_place ~= nil then
		if in_place == true then
			table.insert(args, "-i")
		elseif type(in_place) == "string" then
			-- Use GNU-compatible concatenated form.
			-- For strict BSD compatibility, callers may pass extra = {"-i", ".bak"}.
			validate.non_empty_string(in_place, "in_place")
			if in_place:sub(1, 1) == "-" then error("in_place suffix must not start with '-'") end
			table.insert(args, "-i" .. in_place)
		else
			error("in_place must be boolean or string")
		end
	end

	args_util
		.parser(args, opts)
		:repeatable("expression", "-e", { label = "expression" })
		:repeatable("file", "-f", {
			label = "file",
			validate = function(v, label) validate.not_flag(v, label) end,
		})
		:extra("extra")
end

---@param args string[]
---@param inputs string|string[]|nil
local function apply_inputs(args, inputs)
	if inputs == nil then return end
	if type(inputs) == "string" then
		validate.not_flag(inputs, "input")
		table.insert(args, inputs)
		return
	end
	if type(inputs) == "table" then
		assert(#inputs > 0, "inputs list must be non-empty")
		for _, p in ipairs(inputs) do
			validate.not_flag(p, "input")
			table.insert(args, p)
		end
		return
	end
	error("inputs must be string, string[], or nil")
end

---Construct a sed command.
---
---If `inputs` is nil, sed reads stdin.
---@param inputs string|string[]|nil
---@param opts SedOpts|nil
---@return ward.Cmd
function Sed.run(inputs, opts)
	ensure.bin(Sed.bin, { label = "sed binary" })

	local args = { Sed.bin }
	apply_opts(args, opts)
	apply_inputs(args, inputs)

	return _cmd.cmd(table.unpack(args))
end

---Convenience: add a script via `-e`.
---@param script string
---@param inputs string|string[]|nil
---@param opts SedOpts|nil
---@return ward.Cmd
function Sed.script(script, inputs, opts)
	validate.non_empty_string(script, "script")
	local o = args_util.clone_opts(opts, { "expression", "file", "extra" })
	if o.expression == nil then
		o.expression = script
	else
		-- merge with existing expression(s)
		if type(o.expression) == "string" then
			o.expression = { o.expression, script }
		else
			local e = tbl.clone_array_value(o.expression) or {}
			e[#e + 1] = script
			o.expression = e
		end
	end
	return Sed.run(inputs, o)
end

---Convenience: substitution `s/pattern/repl/g`.
---
---This does not escape pattern/repl; callers should pre-escape if needed.
---@param pattern string
---@param repl string
---@param inputs string|string[]|nil
---@param opts SedOpts|nil
---@return ward.Cmd
function Sed.replace(pattern, repl, inputs, opts)
	validate.non_empty_string(pattern, "pattern")
	validate.non_empty_string(repl, "repl")
	local script = "s/" .. pattern .. "/" .. repl .. "/g"
	return Sed.script(script, inputs, opts)
end

---Convenience: in-place substitution.
---@param pattern string
---@param repl string
---@param inputs string|string[]
---@param backup_suffix string|nil
---@param opts SedOpts|nil
---@return ward.Cmd
function Sed.inplace_replace(pattern, repl, inputs, backup_suffix, opts)
	local o = args_util.clone_opts(opts, { "expression", "file", "extra" })
	if backup_suffix ~= nil then
		validate.non_empty_string(backup_suffix, "backup_suffix")
		o.in_place = backup_suffix
	else
		o.in_place = true
	end
	return Sed.replace(pattern, repl, inputs, o)
end

return {
	Sed = Sed,
}
