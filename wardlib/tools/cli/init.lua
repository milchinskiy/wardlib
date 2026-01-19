-- wardlib.tools.cli
--
-- Declarative CLI argument parsing + automatic help/usage generation.
--
-- Notes:
--   * Returns structured errors (including formatted help/usage text) to the caller.
--   * Designed to parse Ward-provided global `arg` (Lua convention) by default.

local validate = require("wardlib.util.validate")
local rtrim = require("ward.helpers.string").rtrim
local starts_with = require("ward.helpers.string").starts_with
local array_contains = require("ward.helpers.table").contains
local join = require("ward.helpers.table").join
local shallow_copy = require("wardlib.util.table").shallow_copy

local M = {}

-- ---------------------------------------------------------------------------
-- Small local helpers (avoid depending on ward core helpers)
-- ---------------------------------------------------------------------------

local function wrap_text(s, width)
	-- Simple word wrap. Preserves existing newlines.
	width = width or 100
	if width < 20 then width = 20 end
	local lines = {}
	for raw in tostring(s):gmatch("[^\n]*\n?") do
		if raw == "" then break end
		local line = raw
		if line:sub(-1) == "\n" then line = line:sub(1, -2) end
		line = rtrim(line)
		if #line == 0 then
			lines[#lines + 1] = ""
		else
			local cur = ""
			for word in line:gmatch("%S+") do
				if #cur == 0 then
					cur = word
				elseif (#cur + 1 + #word) <= width then
					cur = cur .. " " .. word
				else
					lines[#lines + 1] = cur
					cur = word
				end
			end
			if #cur > 0 then lines[#lines + 1] = cur end
		end
	end
	return table.concat(lines, "\n")
end

local function pad_right(s, n)
	s = tostring(s)
	if #s >= n then return s end
	return s .. string.rep(" ", n - #s)
end

-- ---------------------------------------------------------------------------
-- Suggestion helpers
-- ---------------------------------------------------------------------------

local function levenshtein(a, b, max_dist)
	a = tostring(a)
	b = tostring(b)
	max_dist = max_dist or 2
	if a == b then return 0 end
	local la, lb = #a, #b
	if la == 0 then return lb end
	if lb == 0 then return la end
	if math.abs(la - lb) > max_dist then return max_dist + 1 end
	local prev = {}
	for j = 0, lb do
		prev[j] = j
	end
	for i = 1, la do
		local cur = {}
		cur[0] = i
		local ai = a:sub(i, i)
		local row_min = cur[0]
		for j = 1, lb do
			local cost = (ai == b:sub(j, j)) and 0 or 1
			local ins_cost = cur[j - 1] + 1
			local del_cost = prev[j] + 1
			local sub_cost = prev[j - 1] + cost
			local v = ins_cost
			if del_cost < v then v = del_cost end
			if sub_cost < v then v = sub_cost end
			cur[j] = v
			if v < row_min then row_min = v end
		end
		if row_min > max_dist then return max_dist + 1 end
		prev = cur
	end
	return prev[lb]
end

local function suggest_one(target, candidates, max_dist)
	max_dist = max_dist or 2
	local best = nil
	local best_d = max_dist + 1
	for _, c in ipairs(candidates or {}) do
		local d = levenshtein(target, c, max_dist)
		if d < best_d then
			best_d = d
			best = c
		end
	end
	return best
end

-- ---------------------------------------------------------------------------
-- Coercion / validation
-- ---------------------------------------------------------------------------

local function default_for_option(opt)
	if opt.default ~= nil then return opt.default end
	if opt.kind == "flag" then return false end
	if opt.kind == "count" then return 0 end
	if opt.kind == "values" then return {} end
	return nil
end

local function coerce(spec, raw)
	local typ = spec.type or "string"
	if typ == "string" then return tostring(raw) end
	if typ == "number" then
		local n = tonumber(raw)
		if n == nil then return nil, "expected a number" end
		return n
	end
	if typ == "int" then
		local n = tonumber(raw)
		if n == nil or math.floor(n) ~= n then return nil, "expected an integer" end
		return n
	end
	if typ == "enum" then
		local s = tostring(raw)
		local choices = spec.choices or {}
		if not array_contains(choices, s) then return nil, "expected one of: " .. join(choices, ", ") end
		return s
	end
	return nil, "unknown type: " .. tostring(typ)
end

local function make_error(code, message, token, text)
	return {
		code = code,
		message = message,
		token = token,
		text = text or message,
	}
end

local function emit(on_event, event, state)
	if type(on_event) ~= "function" then return true end
	local ok, a, b = pcall(on_event, event, state)
	if not ok then return false, tostring(a) end
	if a == false then return false, b or "stopped" end
	if a == nil and b ~= nil then return false, b end
	return true
end

local function run_validator(fn, value)
	if type(fn) ~= "function" then return true end
	local ok, a, b = pcall(fn, value)
	if not ok then return false, "validator raised error: " .. tostring(a) end
	if a == false then return false, b or "validation failed" end
	return true
end

local function option_label(opt)
	if opt.long ~= nil then return "--" .. tostring(opt.long) end
	if opt.short ~= nil then return "-" .. tostring(opt.short) end
	return tostring(opt.id)
end

-- ---------------------------------------------------------------------------
-- Spec normalization / indexing
-- ---------------------------------------------------------------------------

local function normalize_spec(spec, opts)
	assert(type(spec) == "table", "spec must be a table")
	opts = opts or {}

	local s = shallow_copy(spec)

	validate.non_empty_string(s.name or "", "spec.name")
	s.name = tostring(s.name)

	s.summary = s.summary or ""
	s.description = s.description or ""

	s.examples = s.examples or {}
	assert(type(s.examples) == "table", "spec.examples must be a table")

	s.epilog = s.epilog or ""
	assert(type(s.epilog) == "string", "spec.epilog must be a string")

	s.options = s.options or {}
	assert(type(s.options) == "table", "spec.options must be a table")

	s.positionals = s.positionals or {}
	assert(type(s.positionals) == "table", "spec.positionals must be a table")

	-- Validate positionals
	for i, p in ipairs(s.positionals) do
		assert(type(p) == "table", "positional spec must be a table")
		validate.non_empty_string(p.id or "", "positional.id")
		validate.non_empty_string(p.metavar or "", "positional.metavar")
		p.kind = p.kind or "value"
		assert(p.kind == "value" or p.kind == "values", "positional.kind must be 'value' or 'values'")
		if p.variadic then assert(i == #s.positionals, "variadic positional must be the last positional") end
		if p.validate ~= nil then assert(type(p.validate) == "function", "positional.validate must be a function") end
	end

	-- Validate options and build uniqueness sets
	local seen_id = {}
	local seen_long = {}
	local seen_short = {}

	for _, o in ipairs(s.options) do
		assert(type(o) == "table", "option spec must be a table")
		validate.non_empty_string(o.id or "", "option.id")
		assert(not seen_id[o.id], "duplicate option id: " .. tostring(o.id))
		seen_id[o.id] = true

		o.kind = o.kind or "flag"
		assert(
			o.kind == "flag" or o.kind == "count" or o.kind == "value" or o.kind == "values",
			"option.kind invalid: " .. tostring(o.kind)
		)

		-- Extended controls
		if o.repeatable == nil then
			o.repeatable = true
		else
			o.repeatable = (o.repeatable == true)
		end

		if o.negatable ~= nil then o.negatable = (o.negatable == true) end
		if o.negatable then
			assert(o.kind == "flag", "option.negatable is only valid for kind='flag'")
			assert(o.long ~= nil, "negatable flag requires option.long")
		end

		if o.max_count ~= nil then
			assert(o.kind == "count", "option.max_count is only valid for kind='count'")
			assert(
				type(o.max_count) == "number" and o.max_count >= 0 and math.floor(o.max_count) == o.max_count,
				"option.max_count must be a non-negative integer"
			)
		end

		if o.validate ~= nil then assert(type(o.validate) == "function", "option.validate must be a function") end

		if o.long ~= nil then
			validate.non_empty_string(o.long, "option.long")
			o.long = tostring(o.long)
			assert(o.long:find("%s") == nil, "option.long must not contain spaces")
			assert(not seen_long[o.long], "duplicate --" .. o.long)
			seen_long[o.long] = true
		end

		if o.short ~= nil then
			validate.non_empty_string(o.short, "option.short")
			o.short = tostring(o.short)
			assert(#o.short == 1, "option.short must be a single letter")
			assert(o.short ~= "-", "option.short must not be '-'")
			assert(not seen_short[o.short], "duplicate -" .. o.short)
			seen_short[o.short] = true
		end

		if o.type == "enum" then
			assert(type(o.choices) == "table" and #o.choices > 0, "enum option must define choices")
		end

		if o.metavar ~= nil then validate.non_empty_string(o.metavar, "option.metavar") end
	end

	-- Auto-help injection
	local auto_help = opts.auto_help ~= false
	if auto_help then
		local help_conflicts = seen_long["help"] or seen_short["h"]
		if not help_conflicts then
			s.options[#s.options + 1] = {
				id = "__help",
				short = "h",
				long = "help",
				kind = "flag",
				help = "Show this help and exit",
				__internal = true,
			}
			seen_id["__help"] = true
			seen_long["help"] = true
			seen_short["h"] = true
		end
	end

	-- Auto-version injection
	local auto_version = opts.auto_version == true
	if auto_version then
		local version_conflicts = seen_long["version"] or seen_short["V"]
		if not version_conflicts then
			s.options[#s.options + 1] = {
				id = "__version",
				short = "V",
				long = "version",
				kind = "flag",
				help = "Show version and exit",
				__internal = true,
			}
			seen_id["__version"] = true
			seen_long["version"] = true
			seen_short["V"] = true
		end
	end

	-- Constraints
	s.constraints = s.constraints or {}
	assert(type(s.constraints) == "table", "spec.constraints must be a table")

	local function norm_constraint_groups(key, min_len)
		local groups = s.constraints[key]
		if groups == nil then
			s.constraints[key] = {}
			return
		end
		assert(type(groups) == "table", "spec.constraints." .. key .. " must be a table")
		local out = {}
		for _, g in ipairs(groups) do
			assert(type(g) == "table", "spec.constraints." .. key .. " group must be a table")
			assert(
				#g >= min_len,
				"spec.constraints." .. key .. " group must have at least " .. tostring(min_len) .. " items"
			)
			local norm = {}
			local seen = {}
			for _, id in ipairs(g) do
				validate.non_empty_string(id or "", "constraint option id")
				id = tostring(id)
				assert(seen_id[id], "unknown option id in constraints: " .. id)
				assert(not seen[id], "duplicate option id in constraints group: " .. id)
				seen[id] = true
				norm[#norm + 1] = id
			end
			out[#out + 1] = norm
		end
		s.constraints[key] = out
	end

	norm_constraint_groups("mutex", 2)
	norm_constraint_groups("one_of", 1)

	-- Subcommands
	s.subcommands = s.subcommands or {}
	assert(type(s.subcommands) == "table", "spec.subcommands must be a table")

	local seen_cmd = {}
	for i, c in ipairs(s.subcommands) do
		assert(type(c) == "table", "subcommand spec must be a table")
		validate.non_empty_string(c.name or "", "subcommand.name")
		local cname = tostring(c.name)
		assert(not seen_cmd[cname], "duplicate subcommand: " .. cname)
		seen_cmd[cname] = true

		-- Normalize aliases
		local aliases = nil
		if c.aliases ~= nil then
			local raw_aliases
			if type(c.aliases) == "string" then
				raw_aliases = { tostring(c.aliases) }
			elseif type(c.aliases) == "table" then
				raw_aliases = {}
				for _, a in ipairs(c.aliases) do
					raw_aliases[#raw_aliases + 1] = tostring(a)
				end
			else
				error("subcommand.aliases must be a string or a table")
			end

			local seen_a = {}
			local norm = {}
			for _, a in ipairs(raw_aliases) do
				validate.non_empty_string(a, "subcommand.aliases")
				a = tostring(a)
				assert(a:find("%s") == nil, "subcommand.alias must not contain spaces: " .. a)
				assert(a ~= cname, "subcommand.alias must not equal command name: " .. cname)
				assert(not seen_a[a], "duplicate alias in subcommand " .. cname .. ": " .. a)
				seen_a[a] = true
				assert(not seen_cmd[a], "duplicate subcommand/alias: " .. a)
				seen_cmd[a] = true
				norm[#norm + 1] = a
			end
			aliases = (#norm > 0) and norm or nil
		end

		-- Recurse
		local cc = shallow_copy(c)
		cc.aliases = aliases
		s.subcommands[i] = normalize_spec(cc, opts)
	end

	return s
end

local function build_index(spec)
	local long_map = {}
	local short_map = {}
	local options_by_id = {}
	local cmd_map = {}
	local cmd_list = {}

	for _, o in ipairs(spec.options) do
		options_by_id[o.id] = o
		if o.long ~= nil then long_map[o.long] = o end
		if o.short ~= nil then short_map[o.short] = o end
	end

	if spec.subcommands ~= nil then
		for _, c in ipairs(spec.subcommands) do
			cmd_map[c.name] = c
			if c.aliases ~= nil then
				for _, a in ipairs(c.aliases) do
					cmd_map[a] = c
				end
			end
			cmd_list[#cmd_list + 1] = c
		end
	end

	return {
		long_map = long_map,
		short_map = short_map,
		options_by_id = options_by_id,
		cmd_map = cmd_map,
		cmd_list = cmd_list,
	}
end

-- ---------------------------------------------------------------------------
-- Parser object
-- ---------------------------------------------------------------------------

local Parser = {}
Parser.__index = Parser

function Parser:_display_name() return self.full_name or tostring(self.spec.name) end

function Parser:_effective_examples()
	local ex = self.spec.examples
	if type(ex) == "table" and #ex > 0 then return ex end
	if self.parent ~= nil and type(self.parent._effective_examples) == "function" then
		return self.parent:_effective_examples()
	end
	return {}
end

function Parser:version()
	local v = self.spec.version
	if v ~= nil and tostring(v) ~= "" then return self:_display_name() .. " " .. tostring(v) .. "\n" end
	return self:_display_name() .. "\n"
end

function Parser:usage()
	local parts = {}
	parts[#parts + 1] = "Usage: " .. self:_display_name()

	if #self.spec.options > 0 then parts[#parts + 1] = "[OPTIONS]" end

	if self.spec.subcommands ~= nil and #self.spec.subcommands > 0 then parts[#parts + 1] = "<COMMAND>" end

	for _, p in ipairs(self.spec.positionals) do
		local mv = tostring(p.metavar)
		if p.variadic then mv = mv .. "..." end
		if p.required then
			parts[#parts + 1] = mv
		else
			parts[#parts + 1] = "[" .. mv .. "]"
		end
	end

	return table.concat(parts, " ")
end

local function format_left_opt(opt)
	local left = ""
	if opt.short ~= nil then left = "-" .. opt.short end
	if opt.long ~= nil then
		if #left > 0 then left = left .. ", " end
		left = left .. "--" .. opt.long
	end
	if opt.kind == "flag" and opt.negatable and opt.long ~= nil then left = left .. ", --no-" .. opt.long end
	if opt.kind == "value" or opt.kind == "values" then
		local mv = opt.metavar or "VALUE"
		left = left .. " " .. mv
	end
	return left
end

local function format_default(opt)
	if opt.default == nil then return nil end
	if opt.kind == "values" and type(opt.default) == "table" then return "[" .. join(opt.default, ", ") .. "]" end
	return tostring(opt.default)
end

function Parser:help(help_opts)
	help_opts = help_opts or {}
	local width = help_opts.width or 100
	local include_description = help_opts.include_description ~= false
	local include_defaults = help_opts.include_defaults ~= false

	local out = {}
	if self.spec.summary ~= nil and #tostring(self.spec.summary) > 0 then
		out[#out + 1] = self:_display_name() .. " - " .. tostring(self.spec.summary)
	else
		out[#out + 1] = self:_display_name()
	end
	out[#out + 1] = ""
	out[#out + 1] = self:usage()

	if include_description and self.spec.description ~= nil and #tostring(self.spec.description) > 0 then
		out[#out + 1] = ""
		out[#out + 1] = wrap_text(tostring(self.spec.description), width)
	end

	-- Options (grouped)
	local opts_list = {}
	for _, o in ipairs(self.spec.options) do
		if not o.__internal then opts_list[#opts_list + 1] = o end
	end
	for _, o in ipairs(self.spec.options) do
		if o.__internal and (o.id == "__help" or o.id == "__version") then opts_list[#opts_list + 1] = o end
	end

	local has_explicit_groups = false
	for _, o in ipairs(self.spec.options) do
		if (not o.__internal) and o.group ~= nil and tostring(o.group) ~= "" then
			has_explicit_groups = true
			break
		end
	end

	local groups = {}
	local group_order = {}
	for _, o in ipairs(opts_list) do
		local g
		if o.__internal and (o.id == "__help" or o.id == "__version") and has_explicit_groups then
			g = "Common options"
		else
			g = o.group
			if g == nil or tostring(g) == "" then
				g = "Options"
			else
				g = tostring(g)
			end
		end
		if groups[g] == nil then
			groups[g] = {}
			group_order[#group_order + 1] = g
		end
		table.insert(groups[g], o)
	end

	for _, g in ipairs(group_order) do
		local list = groups[g]
		if list ~= nil and #list > 0 then
			out[#out + 1] = ""
			out[#out + 1] = g .. ":"

			local rows = {}
			local left_max = 0
			for _, o in ipairs(list) do
				local left = format_left_opt(o)
				if #left > left_max then left_max = #left end
				rows[#rows + 1] = { left = left, opt = o }
			end

			local left_col = math.min(left_max, 32)
			for _, row in ipairs(rows) do
				local o = row.opt
				local left = row.left
				if #left > left_col then left_col = #left end

				local right = o.help or ""
				if include_defaults then
					local d = format_default(o)
					if d ~= nil then
						if #right > 0 then right = right .. " " end
						right = right .. "(default: " .. d .. ")"
					end
				end

				left = pad_right("  " .. left, left_col + 2)
				local right_w = width - (left_col + 4)
				if right_w < 20 then right_w = 20 end
				local wrapped = wrap_text(right, right_w)
				local first = true
				for line in wrapped:gmatch("[^\n]*") do
					if first then
						out[#out + 1] = left .. line
						first = false
					else
						if line == "" then break end
						out[#out + 1] = pad_right("", left_col + 4) .. line
					end
				end
			end
		end
	end

	-- Positionals
	if #self.spec.positionals > 0 then
		out[#out + 1] = ""
		out[#out + 1] = "Arguments:"

		local left_max = 0
		local rows = {}
		for _, p in ipairs(self.spec.positionals) do
			local left = tostring(p.metavar)
			if p.variadic then left = left .. "..." end
			if #left > left_max then left_max = #left end
			rows[#rows + 1] = { left = left, p = p }
		end

		local left_col = math.min(left_max, 32)
		for _, row in ipairs(rows) do
			local p = row.p
			local left = pad_right("  " .. row.left, left_col + 2)
			local right = p.help or ""
			local right_w = width - (left_col + 4)
			if right_w < 20 then right_w = 20 end
			local wrapped = wrap_text(right, right_w)
			local first = true
			for line in wrapped:gmatch("[^\n]*") do
				if first then
					out[#out + 1] = left .. line
					first = false
				else
					if line == "" then break end
					out[#out + 1] = pad_right("", left_col + 4) .. line
				end
			end
		end
	end

	-- Commands
	if self.spec.subcommands ~= nil and #self.spec.subcommands > 0 then
		out[#out + 1] = ""
		out[#out + 1] = "Commands:"

		local left_max = 0
		local rows = {}
		for _, c in ipairs(self.spec.subcommands) do
			local left = tostring(c.name)
			if #left > left_max then left_max = #left end
			rows[#rows + 1] = { left = left, c = c }
		end

		local left_col = math.min(left_max, 32)
		for _, row in ipairs(rows) do
			local c = row.c
			local left = pad_right("  " .. row.left, left_col + 2)
			local right = c.summary or ""
			if c.aliases ~= nil and type(c.aliases) == "table" and #c.aliases > 0 then
				local a = "aliases: " .. join(c.aliases, ", ")
				if #right > 0 then
					right = right .. " (" .. a .. ")"
				else
					right = "(" .. a .. ")"
				end
			end

			local right_w = width - (left_col + 4)
			if right_w < 20 then right_w = 20 end
			local wrapped = wrap_text(right, right_w)
			local first = true
			for line in wrapped:gmatch("[^\n]*") do
				if first then
					out[#out + 1] = left .. line
					first = false
				else
					if line == "" then break end
					out[#out + 1] = pad_right("", left_col + 4) .. line
				end
			end
		end

		out[#out + 1] = ""
		out[#out + 1] = "Run '" .. self:_display_name() .. " <command> --help' for more information."
	end

	-- Examples
	local examples = self:_effective_examples()
	if examples ~= nil and #examples > 0 then
		out[#out + 1] = ""
		out[#out + 1] = "Examples:"

		local rows = {}
		local left_max = 0
		for _, e in ipairs(examples) do
			if type(e) == "string" then
				rows[#rows + 1] = { cmd = e, desc = nil }
				if #e > left_max then left_max = #e end
			elseif type(e) == "table" then
				local cmd = e.cmd or e[1] or ""
				local desc = e.desc or e[2]
				cmd = tostring(cmd)
				if desc ~= nil then desc = tostring(desc) end
				rows[#rows + 1] = { cmd = cmd, desc = desc }
				if #cmd > left_max then left_max = #cmd end
			end
		end

		local left_col = math.min(left_max, 40)
		for _, row in ipairs(rows) do
			local cmd = row.cmd or ""
			local desc = row.desc
			if desc == nil or desc == "" then
				out[#out + 1] = "  " .. cmd
			else
				local left = pad_right("  " .. cmd, left_col + 2)
				local right_w = width - (left_col + 4)
				if right_w < 20 then right_w = 20 end
				local wrapped = wrap_text(desc, right_w)
				local first = true
				for line in wrapped:gmatch("[^\n]*") do
					if first then
						out[#out + 1] = left .. line
						first = false
					else
						if line == "" then break end
						out[#out + 1] = pad_right("", left_col + 4) .. line
					end
				end
			end
		end
	end

	-- Epilog
	if self.spec.epilog ~= nil and #tostring(self.spec.epilog) > 0 then
		out[#out + 1] = ""
		out[#out + 1] = wrap_text(tostring(self.spec.epilog), width)
	end

	return table.concat(out, "\n") .. "\n"
end

-- ---------------------------------------------------------------------------
-- Parsing
-- ---------------------------------------------------------------------------

local function normalize_argv(argv)
	if argv == nil then argv = _G.arg or {} end
	assert(type(argv) == "table", "argv must be a table")

	local argv0 = nil
	if argv[0] ~= nil then argv0 = tostring(argv[0]) end
	return argv, 1, argv0
end

local function format_parse_error(parser, code, message, token)
	local text = message
	if code ~= "help" and code ~= "version" then
		text = text .. "\n\n" .. parser:usage() .. "\n"
		text = text .. "\nRun with --help for more information.\n"
	end
	return make_error(code, message, token, text)
end

local function apply_option(result, seen, opt, raw, token, state)
	-- repeatable control: disallow repeats for non-collection kinds unless repeatable=true
	if opt.kind ~= "values" and opt.repeatable == false and seen[opt.id] then
		return false, { code = "option_repeated", message = "option may not be repeated: " .. option_label(opt) }
	end

	if opt.kind == "flag" then
		local val = true
		if raw == false then
			val = false
		elseif raw == true then
			val = true
		end

		local okv, verr = run_validator(opt.validate, val)
		if not okv then return false, { code = "invalid_value", message = verr } end

		result.values[opt.id] = val
		seen[opt.id] = true
		local ok, err =
			emit(state.on_event, { type = "option", id = opt.id, value = val, token = token, raw = raw }, state)
		if not ok then return false, { code = "callback_error", message = err } end
		if type(opt.on) == "function" then opt.on(val, { type = "option", id = opt.id, token = token }, state) end
		return true
	end

	if opt.kind == "count" then
		local v = result.values[opt.id]
		if type(v) ~= "number" then v = 0 end
		if opt.max_count ~= nil and (v + 1) > opt.max_count then
			return false,
				{ code = "too_many_occurrences", message = "too many occurrences of option: " .. option_label(opt) }
		end
		v = v + 1

		local okv, verr = run_validator(opt.validate, v)
		if not okv then return false, { code = "invalid_value", message = verr } end

		result.values[opt.id] = v
		seen[opt.id] = true
		local ok, err =
			emit(state.on_event, { type = "option", id = opt.id, value = v, token = token, raw = raw }, state)
		if not ok then return false, { code = "callback_error", message = err } end
		if type(opt.on) == "function" then opt.on(v, { type = "option", id = opt.id, token = token }, state) end
		return true
	end

	-- value/values
	local v, cerr = coerce(opt, raw)
	if v == nil then return false, { code = "invalid_value", message = cerr } end

	local okv, verr = run_validator(opt.validate, v)
	if not okv then return false, { code = "invalid_value", message = verr } end

	seen[opt.id] = true

	if opt.kind == "values" then
		if type(result.values[opt.id]) ~= "table" then result.values[opt.id] = {} end
		table.insert(result.values[opt.id], v)
		local ok, err =
			emit(state.on_event, { type = "option", id = opt.id, value = v, token = token, raw = raw }, state)
		if not ok then return false, { code = "callback_error", message = err } end
		if type(opt.on) == "function" then opt.on(v, { type = "option", id = opt.id, token = token }, state) end
		return true
	end

	result.values[opt.id] = v
	local ok, err = emit(state.on_event, { type = "option", id = opt.id, value = v, token = token, raw = raw }, state)
	if not ok then return false, { code = "callback_error", message = err } end
	if type(opt.on) == "function" then opt.on(v, { type = "option", id = opt.id, token = token }, state) end
	return true
end

local function apply_positional(result, ps, raw, state, index)
	local v, cerr = coerce(ps, raw)
	if v == nil then return false, { code = "invalid_value", message = tostring(cerr) } end

	local okv, verr = run_validator(ps.validate, v)
	if not okv then return false, { code = "invalid_value", message = tostring(verr) } end

	if ps.kind == "values" or ps.variadic then
		if type(result.positionals[ps.id]) ~= "table" then result.positionals[ps.id] = {} end
		table.insert(result.positionals[ps.id], v)
		local ok, err =
			emit(state.on_event, { type = "positional", id = ps.id, value = v, index = index, raw = raw }, state)
		if not ok then return false, { code = "callback_error", message = tostring(err) } end
		if type(ps.on) == "function" then ps.on(v, { type = "positional", id = ps.id, index = index }, state) end
		return true
	end

	result.positionals[ps.id] = v
	local ok, err =
		emit(state.on_event, { type = "positional", id = ps.id, value = v, index = index, raw = raw }, state)
	if not ok then return false, { code = "callback_error", message = tostring(err) } end
	if type(ps.on) == "function" then ps.on(v, { type = "positional", id = ps.id, index = index }, state) end
	return true
end

function Parser:parse(argv, parse_opts)
	parse_opts = parse_opts or {}

	local argv0
	argv, _, argv0 = normalize_argv(argv)

	local start_index = parse_opts.start_index or 1
	local allow_unknown = parse_opts.allow_unknown == true
	local stop_at_first_positional = parse_opts.stop_at_first_positional == true

	local state = {
		parser = self,
		on_event = parse_opts.on_event,
	}

	local result = {
		values = {},
		positionals = {},
		rest = {},
		cmd = nil,
		argv0 = argv0 or self:_display_name(),
	}

	-- Defaults
	for _, opt in ipairs(self.spec.options) do
		result.values[opt.id] = default_for_option(opt)
	end
	for _, ps in ipairs(self.spec.positionals) do
		if ps.kind == "values" or ps.variadic then result.positionals[ps.id] = {} end
	end

	local seen = {}
	local mode = "options"
	local pos_index = 1

	local function push_unknown(tok)
		result.rest[#result.rest + 1] = tok
		emit(state.on_event, { type = "unknown", token = tok }, state)
	end

	local function make_cmd_node(cmd_spec, sub_result)
		local path = { cmd_spec.name }
		if sub_result.cmd ~= nil and type(sub_result.cmd.path) == "table" then
			for _, v in ipairs(sub_result.cmd.path) do
				path[#path + 1] = v
			end
		end
		return {
			name = path[#path],
			path = path,
			values = sub_result.values,
			positionals = sub_result.positionals,
			rest = sub_result.rest,
			cmd = sub_result.cmd,
		}
	end

	local function parse_subcommand(cmd_spec, i_at)
		local cmd_parser = setmetatable({
			spec = cmd_spec,
			index = build_index(cmd_spec),
			opts = self.opts,
			parent = self,
			full_name = self:_display_name() .. " " .. tostring(cmd_spec.name),
		}, Parser)

		local sub_argv = { [0] = argv0 or self:_display_name() }
		local k = 1
		for j = i_at + 1, #argv do
			sub_argv[k] = argv[j]
			k = k + 1
		end

		local ok, sub = cmd_parser:parse(sub_argv, {
			start_index = 1,
			allow_unknown = allow_unknown,
			stop_at_first_positional = stop_at_first_positional,
			on_event = parse_opts.on_event,
		})
		if not ok then return false, sub end
		return true, make_cmd_node(cmd_spec, sub)
	end

	local i = start_index
	while i <= #argv do
		local tok = argv[i]
		if tok == nil then break end
		tok = tostring(tok)

		if mode == "options" and tok == "--" then
			mode = "positional"
			i = i + 1
			goto continue
		end

		-- Long option
		if mode == "options" and starts_with(tok, "--") and tok ~= "--" then
			local body = tok:sub(3)
			local eq = body:find("=", 1, true)
			local name = body
			local raw = nil
			if eq ~= nil then
				name = body:sub(1, eq - 1)
				raw = body:sub(eq + 1)
			end

			local opt = self.index.long_map[name]
			local negated = false
			if not opt and raw == nil and starts_with(name, "no-") then
				local base = name:sub(4)
				local o2 = self.index.long_map[base]
				if o2 ~= nil and o2.kind == "flag" and o2.negatable then
					opt = o2
					negated = true
					name = base
				end
			end

			if not opt then
				if allow_unknown then
					push_unknown(tok)
					i = i + 1
					goto continue
				end

				local candidates = {}
				for key, _ in pairs(self.index.long_map) do
					candidates[#candidates + 1] = tostring(key)
				end
				for _, o in ipairs(self.spec.options) do
					if o.kind == "flag" and o.negatable and o.long ~= nil then
						candidates[#candidates + 1] = "no-" .. tostring(o.long)
					end
				end
				local sug = suggest_one(name, candidates, 2)
				local msg = "unknown option: --" .. name
				if sug ~= nil then msg = msg .. " (did you mean --" .. sug .. "?)" end
				return false, format_parse_error(self, "unknown_option", msg, tok)
			end

			if opt.__internal and opt.id == "__help" then
				emit(state.on_event, { type = "help" }, state)
				return false, make_error("help", "help requested", tok, self:help())
			end
			if opt.__internal and opt.id == "__version" then
				emit(state.on_event, { type = "version" }, state)
				return false, make_error("version", "version requested", tok, self:version())
			end

			if opt.kind == "value" or opt.kind == "values" then
				if raw == nil then
					i = i + 1
					raw = argv[i]
					if raw == nil then
						return false,
							format_parse_error(self, "missing_value", "missing value for option: --" .. name, tok)
					end
				end
			end

			local opt_token = "--" .. name
			local raw_apply = raw
			if negated then
				opt_token = "--no-" .. name
				---@diagnostic disable-next-line: cast-local-type
				raw_apply = false
			end

			local ok_apply, err_apply = apply_option(result, seen, opt, raw_apply, opt_token, state)
			if not ok_apply then
				if type(err_apply) == "table" and err_apply.code ~= nil then
					return false, format_parse_error(self, err_apply.code, err_apply.message, tok)
				end
				return false,
					format_parse_error(
						self,
						"invalid_value",
						"invalid value for --" .. name .. ": " .. tostring(err_apply),
						tok
					)
			end

			i = i + 1
			goto continue
		end

		-- Short option or bundle (single-dash, not '--...')
		if mode == "options" and starts_with(tok, "-") and not starts_with(tok, "--") and tok ~= "-" then
			local body = tok:sub(2)
			if #body > 0 then
				local j = 1
				while j <= #body do
					local ch = body:sub(j, j)
					local opt = self.index.short_map[ch]
					if not opt then
						if allow_unknown then
							push_unknown("-" .. ch)
							j = j + 1
						else
							return false,
								format_parse_error(self, "unknown_option", "unknown option: -" .. ch, "-" .. ch)
						end
					else
						if opt.__internal and opt.id == "__help" then
							emit(state.on_event, { type = "help" }, state)
							return false, make_error("help", "help requested", "-" .. ch, self:help())
						end
						if opt.__internal and opt.id == "__version" then
							emit(state.on_event, { type = "version" }, state)
							return false, make_error("version", "version requested", "-" .. ch, self:version())
						end

						if opt.kind == "value" or opt.kind == "values" then
							local raw = nil
							if j < #body then
								raw = body:sub(j + 1)
								j = #body -- consumed remainder
							else
								i = i + 1
								raw = argv[i]
								if raw == nil then
									return false,
										format_parse_error(
											self,
											"missing_value",
											"missing value for option: -" .. ch,
											"-" .. ch
										)
								end
							end

							local ok_apply, err_apply = apply_option(result, seen, opt, raw, "-" .. ch, state)
							if not ok_apply then
								if type(err_apply) == "table" and err_apply.code ~= nil then
									return false, format_parse_error(self, err_apply.code, err_apply.message, "-" .. ch)
								end
								return false,
									format_parse_error(
										self,
										"invalid_value",
										"invalid value for -" .. ch .. ": " .. tostring(err_apply),
										"-" .. ch
									)
							end
							j = #body + 1
						else
							local ok_apply, err_apply = apply_option(result, seen, opt, nil, "-" .. ch, state)
							if not ok_apply then
								if type(err_apply) == "table" and err_apply.code ~= nil then
									return false, format_parse_error(self, err_apply.code, err_apply.message, "-" .. ch)
								end
								return false,
									format_parse_error(
										self,
										"invalid_value",
										"invalid value for -" .. ch .. ": " .. tostring(err_apply),
										"-" .. ch
									)
							end
							j = j + 1
						end
					end
				end
			end

			i = i + 1
			goto continue
		end

		-- Command selection
		if
			mode == "options"
			and self.spec.subcommands ~= nil
			and #self.spec.subcommands > 0
			and (not starts_with(tok, "-"))
		then
			local cmd_spec = self.index.cmd_map[tok]
			if cmd_spec ~= nil then
				emit(state.on_event, {
					type = "command",
					path = { cmd_spec.name },
					name = cmd_spec.name,
					token = tok,
					alias = (tok ~= cmd_spec.name) and tok or nil,
				}, state)
				local ok_cmd, cmd_node = parse_subcommand(cmd_spec, i)
				if not ok_cmd then return false, cmd_node end
				result.cmd = cmd_node
				break
			elseif #self.spec.positionals == 0 and pos_index == 1 then
				local candidates = {}
				for _, c in ipairs(self.spec.subcommands) do
					candidates[#candidates + 1] = tostring(c.name)
				end
				local sug = suggest_one(tok, candidates, 2)
				local msg = "unknown command: " .. tok
				if sug ~= nil then msg = msg .. " (did you mean '" .. sug .. "'?)" end
				return false, format_parse_error(self, "unknown_command", msg, tok)
			end
		end

		-- Positionals
		if mode == "options" and stop_at_first_positional then mode = "positional" end

		local ps = self.spec.positionals[pos_index]
		if not ps then
			if allow_unknown then
				result.rest[#result.rest + 1] = tok
				emit(state.on_event, { type = "rest", token = tok }, state)
				i = i + 1
				goto continue
			end
			return false,
				format_parse_error(self, "too_many_positionals", "too many positional arguments: " .. tok, tok)
		end

		local ok_pos, err_pos = apply_positional(result, ps, tok, state, pos_index)
		if not ok_pos then
			if type(err_pos) == "table" and err_pos.code ~= nil then
				return false, format_parse_error(self, err_pos.code, err_pos.message, tok)
			end
			return false,
				format_parse_error(
					self,
					"invalid_value",
					"invalid value for " .. ps.metavar .. ": " .. tostring(err_pos),
					tok
				)
		end

		if not ps.variadic then pos_index = pos_index + 1 end

		i = i + 1
		::continue::
	end

	-- Required checks
	for _, opt in ipairs(self.spec.options) do
		if opt.required and not seen[opt.id] then
			local label = opt.long and ("--" .. opt.long) or (opt.short and ("-" .. opt.short) or opt.id)
			return false, format_parse_error(self, "missing_required", "missing required option: " .. label, label)
		end
	end

	for _, ps in ipairs(self.spec.positionals) do
		if ps.required then
			if ps.kind == "values" or ps.variadic then
				local arr = result.positionals[ps.id]
				if type(arr) ~= "table" or #arr == 0 then
					return false,
						format_parse_error(
							self,
							"missing_required",
							"missing required positional: " .. ps.metavar,
							ps.metavar
						)
				end
			else
				if result.positionals[ps.id] == nil then
					return false,
						format_parse_error(
							self,
							"missing_required",
							"missing required positional: " .. ps.metavar,
							ps.metavar
						)
				end
			end
		end
	end

	-- Constraints
	local c = self.spec.constraints or {}
	for _, g in ipairs(c.mutex or {}) do
		local chosen = {}
		for _, id in ipairs(g) do
			if seen[id] then
				local opt = self.index.options_by_id[id] or { id = id }
				chosen[#chosen + 1] = option_label(opt)
			end
		end
		if #chosen > 1 then
			return false,
				format_parse_error(
					self,
					"mutually_exclusive",
					"options are mutually exclusive: " .. join(chosen, ", "),
					chosen[1]
				)
		end
	end

	for _, g in ipairs(c.one_of or {}) do
		local any = false
		for _, id in ipairs(g) do
			if seen[id] then
				any = true
				break
			end
		end
		if not any then
			local labels = {}
			for _, id in ipairs(g) do
				local opt = self.index.options_by_id[id] or { id = id }
				labels[#labels + 1] = option_label(opt)
			end
			return false,
				format_parse_error(self, "missing_one_of", "missing one of: " .. join(labels, ", "), labels[1])
		end
	end

	return true, result
end

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------

function M.new(spec, opts)
	opts = opts or {}
	local nspec = normalize_spec(spec, opts)
	local index = build_index(nspec)
	return setmetatable({ spec = nspec, index = index, opts = opts }, Parser)
end

return M
