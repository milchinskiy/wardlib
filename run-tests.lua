-- run-tests.lua
-- Wardlib test runner:
--   - Discovers **/*.test.lua (recursive) from current working directory
--   - Runs them via wardlib.tinytest (or local tinytest module)
--
-- Usage:
--   ward run ./run-tests.lua
--   ward run ./run-tests.lua -- --only SUBSTR
--   ward run ./run-tests.lua -- --fail-fast
--   ward run ./run-tests.lua -- --list
--   ward run ./run-tests.lua -- --pattern "**/*.test.lua" --pattern "extra/*.test.lua"
--   ward run ./run-tests.lua -- path/to/specific.test.lua
--   ward run ./run-tests.lua -- "tests/**/*.test.lua"

local fs = require("ward.fs")
local term = require("ward.term")

-- Adjust this require path to match where you place tinytest.lua inside wardlib.
-- Common options:
--   * require("wardlib.tinytest")
--   * require("tinytest")
local tinytest = require("wardlib.test.tinytest")

local function has_glob_chars(s)
	return s:find("*", 1, true) ~= nil or s:find("?", 1, true) ~= nil or s:find("[", 1, true) ~= nil
end

local function dedup_sorted(list)
	table.sort(list)
	local out = {}
	local last = nil
	for _, p in ipairs(list) do
		if p ~= last then
			out[#out + 1] = p
			last = p
		end
	end
	return out
end

local function expand_specs(specs)
	-- Accept:
	--  - existing file paths
	--  - glob patterns
	local out = {}
	for _, s in ipairs(specs) do
		if has_glob_chars(s) then
			for _, p in ipairs(fs.glob(s)) do
				out[#out + 1] = p
			end
		else
			if fs.is_exists(s) then
				out[#out + 1] = s
			else
				-- treat as pattern (useful for "tests/**/*.test.lua" without obvious glob chars)
				for _, p in ipairs(fs.glob(s)) do
					out[#out + 1] = p
				end
			end
		end
	end
	return dedup_sorted(out)
end

local function discover(patterns)
	local files = {}
	for _, pat in ipairs(patterns) do
		for _, p in ipairs(fs.glob(pat)) do
			files[#files + 1] = p
		end
	end
	return dedup_sorted(files)
end

local function parse_argv(argv)
	assert(type(argv) == "table", "argv must be a table")

	local opts = { list = false, only = nil, fail_fast = false }
	local patterns = { "**/*.test.lua" }
	local specs = {}

	local function require_value(flag, idx)
		local v = argv[idx]
		assert(v ~= nil and v ~= "", flag .. " requires a value")
		return v
	end

	local i = 1
	while i <= #argv do
		local a = argv[i]
		if a == "--list" then
			opts.list = true
		elseif a == "--only" then
			i = i + 1
			opts.only = require_value("--only", i)
		elseif a == "--fail-fast" then
			opts.fail_fast = true
		elseif a == "--pattern" then
			i = i + 1
			local pat = require_value("--pattern", i)
			patterns[#patterns + 1] = pat
		else
			specs[#specs + 1] = a
		end
		i = i + 1
	end

	return opts, patterns, specs
end

local function main(argv)
	local opts, patterns, specs = parse_argv(argv)

	local files
	if #specs > 0 then
		files = expand_specs(specs)
	else
		files = discover(patterns)
	end

	if #files == 0 then
		term.eprintln("No test files found.")
		term.eprintln("Patterns: " .. table.concat(patterns, ", "))
		return { total = 0, passed = 0, failed = 0, skipped = 0, suites = {} }
	end

	term.println(string.format("Discovered %d test file(s).", #files))

	local r = tinytest.run(files, {
		list = opts.list,
		only = opts.only,
		fail_fast = opts.fail_fast,
	})

	if (not opts.list) and r.failed > 0 then
		require("ward.process").exit(1)
	end
	return r
end

return main(arg)
