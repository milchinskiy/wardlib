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
local _env = require("ward.env")
local _fs = require("ward.fs")

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

---@param bin string
local function validate_bin(bin)
	assert(type(bin) == "string" and #bin > 0, "sed binary is not set")
	if bin:find("/", 1, true) then
		assert(_fs.is_exists(bin), string.format("sed binary does not exist: %s", bin))
		assert(_fs.is_executable(bin), string.format("sed binary is not executable: %s", bin))
	else
		assert(_env.is_in_path(bin), string.format("sed binary is not in PATH: %s", bin))
	end
end

---@param s any
---@param label string
local function validate_non_empty_string(s, label)
	assert(type(s) == "string" and #s > 0, label .. " must be a non-empty string")
end

---@param value string
---@param label string
local function validate_not_flag(value, label)
	validate_non_empty_string(value, label)
	assert(value:sub(1, 1) ~= "-", label .. " must not start with '-': " .. tostring(value))
end

---@param scripts string|string[]
---@param flag string
---@param label string
---@param args string[]
local function add_repeatable(args, scripts, flag, label)
	if type(scripts) == "string" then
		validate_non_empty_string(scripts, label)
		table.insert(args, flag)
		table.insert(args, scripts)
		return
	end
	assert(type(scripts) == "table", label .. " must be a string or string[]")
	assert(#scripts > 0, label .. " must be non-empty")
	for _, s in ipairs(scripts) do
		validate_non_empty_string(s, label)
		table.insert(args, flag)
		table.insert(args, s)
	end
end

---@param args string[]
---@param opts SedOpts|nil
local function apply_opts(args, opts)
	opts = opts or {}

	if opts.extended then
		table.insert(args, "-E")
	end
	if opts.quiet then
		table.insert(args, "-n")
	end
	if opts.null_data then
		table.insert(args, "-z")
	end
	if opts.follow_symlinks then
		table.insert(args, "--follow-symlinks")
	end
	if opts.posix then
		table.insert(args, "--posix")
	end
	if opts.sandbox then
		table.insert(args, "--sandbox")
	end

	-- in-place handling
	local in_place = opts.in_place
	if opts.backup_suffix ~= nil then
		validate_non_empty_string(opts.backup_suffix, "backup_suffix")
		in_place = opts.backup_suffix
	end
	if in_place ~= nil then
		if in_place == true then
			table.insert(args, "-i")
		elseif type(in_place) == "string" then
			-- Use GNU-compatible concatenated form.
			-- For strict BSD compatibility, callers may pass extra = {"-i", ".bak"}.
			validate_non_empty_string(in_place, "in_place")
			if in_place:sub(1, 1) == "-" then
				error("in_place suffix must not start with '-'")
			end
			table.insert(args, "-i" .. in_place)
		else
			error("in_place must be boolean or string")
		end
	end

	if opts.expression ~= nil then
		add_repeatable(args, opts.expression, "-e", "expression")
	end
	if opts.file ~= nil then
		add_repeatable(args, opts.file, "-f", "file")
	end

	if opts.extra ~= nil then
		assert(type(opts.extra) == "table", "extra must be an array")
		for _, v in ipairs(opts.extra) do
			table.insert(args, tostring(v))
		end
	end
end

---@param args string[]
---@param inputs string|string[]|nil
local function apply_inputs(args, inputs)
	if inputs == nil then
		return
	end
	if type(inputs) == "string" then
		validate_not_flag(inputs, "input")
		table.insert(args, inputs)
		return
	end
	if type(inputs) == "table" then
		assert(#inputs > 0, "inputs list must be non-empty")
		for _, p in ipairs(inputs) do
			validate_not_flag(p, "input")
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
	validate_bin(Sed.bin)

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
	validate_non_empty_string(script, "script")
	opts = opts or {}
	if opts.expression == nil then
		opts.expression = script
	else
		-- merge with existing expression(s)
		if type(opts.expression) == "string" then
			opts.expression = { opts.expression, script }
		else
			table.insert(opts.expression, script)
		end
	end
	return Sed.run(inputs, opts)
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
	validate_non_empty_string(pattern, "pattern")
	validate_non_empty_string(repl, "repl")
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
	opts = opts or {}
	if backup_suffix ~= nil then
		validate_non_empty_string(backup_suffix, "backup_suffix")
		opts.in_place = backup_suffix
	else
		opts.in_place = true
	end
	return Sed.replace(pattern, repl, inputs, opts)
end

return {
	Sed = Sed,
}
