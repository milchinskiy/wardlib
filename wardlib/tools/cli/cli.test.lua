---@diagnostic disable: duplicate-set-field

-- Tinytest suite for tools.cli
--
-- This suite intentionally avoids any ward.* mocking; the parser is pure-Lua.

return function(tinytest)
	local t = tinytest.new({ name = "tools.cli" })

	local function make_parser()
		local cli = require("wardlib.tools.cli")
		return cli.new({
			name = "mytool",
			summary = "Example tool",
			options = {
				{ id = "verbose", short = "v", long = "verbose", kind = "count", help = "Increase verbosity" },
				{
					id = "config",
					short = "c",
					long = "config",
					kind = "value",
					type = "string",
					metavar = "FILE",
					help = "Config file",
				},
				{
					id = "mode",
					long = "mode",
					kind = "value",
					type = "enum",
					choices = { "fast", "safe" },
					default = "safe",
					help = "Mode",
				},
				{ id = "dry_run", long = "dry-run", kind = "flag", negatable = true, help = "Do not apply changes" },
			},
			positionals = {
				{
					id = "input",
					metavar = "INPUT",
					kind = "value",
					type = "string",
					required = true,
					help = "Input file",
				},
				{
					id = "rest",
					metavar = "ARGS",
					kind = "values",
					type = "string",
					variadic = true,
					help = "Extra args",
				},
			},
		})
	end

	t:test("--dry-run sets flag", function()
		local p = make_parser()
		local ok, out = p:parse({ [0] = "mytool", "--dry-run", "in.txt" })
		t:eq(ok, true)
		t:eq(out.values.dry_run, true)
		t:eq(out.positionals.input, "in.txt")
	end)

	t:test("--config value consumes next token", function()
		local p = make_parser()
		local ok, out = p:parse({ [0] = "mytool", "--config", "a.conf", "in.txt" })
		t:eq(ok, true)
		t:eq(out.values.config, "a.conf")
		t:eq(out.positionals.input, "in.txt")
	end)

	t:test("--config=value consumes inline", function()
		local p = make_parser()
		local ok, out = p:parse({ [0] = "mytool", "--config=a.conf", "in.txt" })
		t:eq(ok, true)
		t:eq(out.values.config, "a.conf")
		t:eq(out.positionals.input, "in.txt")
	end)

	t:test("-vvv increments count", function()
		local p = make_parser()
		local ok, out = p:parse({ [0] = "mytool", "-vvv", "in.txt" })
		t:eq(ok, true)
		t:eq(out.values.verbose, 3)
	end)

	t:test("-cFILE consumes remainder", function()
		local p = make_parser()
		local ok, out = p:parse({ [0] = "mytool", "-ca.conf", "in.txt" })
		t:eq(ok, true)
		t:eq(out.values.config, "a.conf")
	end)

	t:test("-- terminates option parsing", function()
		local p = make_parser()
		local ok, out = p:parse({ [0] = "mytool", "--config", "a.conf", "--", "in.txt", "--not-an-opt" })
		t:eq(ok, true)
		t:eq(out.positionals.input, "in.txt")
		t:eq(#out.positionals.rest, 1)
		t:eq(out.positionals.rest[1], "--not-an-opt")
	end)

	t:test("missing required positional returns missing_required", function()
		local p = make_parser()
		local ok, err = p:parse({ [0] = "mytool", "--dry-run" })
		t:eq(ok, false)
		t:eq(err.code, "missing_required")
		t:match(err.text, "Usage:")
		t:match(err.text, "Run with %-%-help")
	end)

	t:test("invalid enum returns invalid_value", function()
		local p = make_parser()
		local ok, err = p:parse({ [0] = "mytool", "--mode", "weird", "in.txt" })
		t:eq(ok, false)
		t:eq(err.code, "invalid_value")
		t:match(err.text, "expected one of")
	end)

	t:test("--help returns code=help and includes usage", function()
		local p = make_parser()
		local ok, err = p:parse({ [0] = "mytool", "--help" })
		t:eq(ok, false)
		t:eq(err.code, "help")
		t:match(err.text, "Usage:")
		t:match(err.text, "Options:")
	end)

	t:test("unknown option errors by default", function()
		local p = make_parser()
		local ok, err = p:parse({ [0] = "mytool", "--weird", "in.txt" })
		t:eq(ok, false)
		t:eq(err.code, "unknown_option")
		t:match(err.text, "unknown option")
	end)

	t:test("allow_unknown collects unknown tokens", function()
		local p = make_parser()
		local ok, out = p:parse({ [0] = "mytool", "--weird", "--dry-run", "in.txt" }, { allow_unknown = true })
		t:eq(ok, true)
		t:eq(out.values.dry_run, true)
		t:eq(#out.rest, 1)
		t:eq(out.rest[1], "--weird")
	end)

	t:test("short bundle with value option not last consumes remainder", function()
		local cli = require("wardlib.tools.cli")
		local p = cli.new({
			name = "mytool",
			version = "1.2.3",
			options = {
				{ id = "config", short = "c", long = "config", kind = "value" },
			},
			positionals = { { id = "input", metavar = "INPUT", kind = "value", required = true } },
		}, { auto_version = true })

		-- '-c' consumes the remainder of the bundle. The trailing 'V' is part of the value,
		-- not a separate '-V' version flag.
		local ok, out = p:parse({ [0] = "mytool", "-cfooV", "in.txt" })
		t:eq(ok, true)
		t:eq(out.values.config, "fooV")
		t:eq(out.positionals.input, "in.txt")
	end)

	t:test("allow_unknown collects unknown short from a mixed bundle", function()
		local cli = require("wardlib.tools.cli")
		local p = cli.new({
			name = "mytool",
			options = {
				{ id = "all", short = "a", long = "all", kind = "flag" },
				{ id = "verbose", short = "v", long = "verbose", kind = "count" },
			},
			positionals = { { id = "input", metavar = "INPUT", kind = "value", required = true } },
		})

		-- '-x' is unknown but should be collected (in-order) when allow_unknown=true.
		local ok, out = p:parse({ [0] = "mytool", "-avx", "in.txt" }, { allow_unknown = true })
		t:eq(ok, true)
		t:eq(out.values.all, true)
		t:eq(out.values.verbose, 1)
		t:eq(out.positionals.input, "in.txt")
		t:eq(#out.rest, 1)
		t:eq(out.rest[1], "-x")
	end)

	t:test("subcommand parse returns nested cmd", function()
		local cli = require("wardlib.tools.cli")
		local p = cli.new({
			name = "mytool",
			version = "1.2.3",
			summary = "Tool with subcommands",
			options = {
				{ id = "verbose", short = "v", long = "verbose", kind = "count", help = "Increase verbosity" },
			},
			subcommands = {
				{
					name = "run",
					summary = "Run the tool",
					options = {
						{
							id = "jobs",
							short = "j",
							long = "jobs",
							kind = "value",
							type = "int",
							default = 1,
							metavar = "N",
							help = "Number of jobs",
						},
					},
					positionals = {
						{
							id = "target",
							metavar = "TARGET",
							kind = "value",
							type = "string",
							required = true,
							help = "Target to run",
						},
					},
				},
			},
		}, { auto_version = true })

		local ok, out = p:parse({ [0] = "mytool", "-v", "run", "--jobs", "4", "all" })
		t:eq(ok, true)
		t:eq(out.values.verbose, 1)
		t:eq(out.cmd ~= nil, true)
		t:eq(out.cmd.name, "run")
		t:eq(out.cmd.values.jobs, 4)
		t:eq(out.cmd.positionals.target, "all")
	end)

	t:test("subcommand --help shows command usage", function()
		local cli = require("wardlib.tools.cli")
		local p = cli.new({
			name = "mytool",
			version = "1.2.3",
			summary = "Tool with subcommands",
			subcommands = {
				{ name = "run", summary = "Run", options = {}, positionals = {} },
			},
		}, { auto_version = true })

		local ok, err = p:parse({ [0] = "mytool", "run", "--help" })
		t:eq(ok, false)
		t:eq(err.code, "help")
		t:match(err.text, "Usage: mytool run")
	end)

	t:test("--version returns code=version", function()
		local cli = require("wardlib.tools.cli")
		local p = cli.new({
			name = "mytool",
			version = "1.2.3",
			summary = "Tool with version",
		}, { auto_version = true })

		local ok, err = p:parse({ [0] = "mytool", "--version" })
		t:eq(ok, false)
		t:eq(err.code, "version")
		t:match(err.text, "1.2.3")
	end)

	t:test("unknown command returns unknown_command", function()
		local cli = require("wardlib.tools.cli")
		local p = cli.new({
			name = "mytool",
			subcommands = { { name = "run", summary = "Run", options = {}, positionals = {} } },
		}, { auto_version = true })

		local ok, err = p:parse({ [0] = "mytool", "nope" })
		t:eq(ok, false)
		t:eq(err.code, "unknown_command")
	end)

	t:test("help groups options and shows examples/epilog", function()
		local cli = require("wardlib.tools.cli")
		local p = cli.new({
			name = "mytool",
			summary = "Grouped options",
			examples = {
				{ "mytool run TARGET", "Run a target" },
				"mytool --help",
			},
			epilog = "For more info see docs.",
			options = {
				{
					id = "verbose",
					short = "v",
					long = "verbose",
					kind = "count",
					help = "Verbosity",
					group = "Common options",
				},
				{
					id = "output",
					long = "output",
					kind = "value",
					metavar = "FILE",
					help = "Output file",
					group = "Output options",
				},
			},
			subcommands = { { name = "run", summary = "Run", options = {}, positionals = {} } },
		}, { auto_version = true })

		local ok, err = p:parse({ [0] = "mytool", "--help" })
		t:eq(ok, false)
		t:eq(err.code, "help")
		t:match(err.text, "Common options:")
		t:match(err.text, "Output options:")
		t:match(err.text, "Examples:")
		t:match(err.text, "mytool run TARGET")
		t:match(err.text, "For more info")
		t:match(err.text, "Run 'mytool <command> %-%-help'")
	end)

	t:test("subcommand aliases resolve to canonical name", function()
		local cli = require("wardlib.tools.cli")
		local p = cli.new({
			name = "mytool",
			summary = "Aliases",
			subcommands = {
				{ name = "run", aliases = { "r", "execute" }, summary = "Run", options = {}, positionals = {} },
			},
		})

		local ok, out = p:parse({ [0] = "mytool", "r" })
		t:eq(ok, true)
		t:eq(out.cmd ~= nil, true)
		t:eq(out.cmd.name, "run")
		-- Path is always canonical
		t:eq(out.cmd.path[1], "run")
	end)

	t:test("help lists subcommand aliases", function()
		local cli = require("wardlib.tools.cli")
		local p = cli.new({
			name = "mytool",
			summary = "Aliases",
			subcommands = {
				{ name = "run", aliases = { "r", "execute" }, summary = "Run", options = {}, positionals = {} },
			},
		})

		local ok, err = p:parse({ [0] = "mytool", "--help" })
		t:eq(ok, false)
		t:eq(err.code, "help")
		t:match(err.text, "aliases: r")
		t:match(err.text, "execute")
	end)

	t:test("subcommand help inherits examples from parent", function()
		local cli = require("wardlib.tools.cli")
		local p = cli.new({
			name = "mytool",
			summary = "Examples",
			examples = { "mytool run TARGET" },
			subcommands = {
				{ name = "run", summary = "Run", options = {}, positionals = {} },
			},
		})

		local ok, err = p:parse({ [0] = "mytool", "run", "--help" })
		t:eq(ok, false)
		t:eq(err.code, "help")
		t:match(err.text, "Examples:")
		t:match(err.text, "mytool run TARGET")
	end)

	t:test("subcommand examples override parent examples", function()
		local cli = require("wardlib.tools.cli")
		local p = cli.new({
			name = "mytool",
			summary = "Examples",
			examples = { "root example" },
			subcommands = {
				{ name = "run", summary = "Run", examples = { "mytool run --help" }, options = {}, positionals = {} },
			},
		})

		local ok, err = p:parse({ [0] = "mytool", "run", "--help" })
		t:eq(ok, false)
		t:eq(err.code, "help")
		t:match(err.text, "mytool run %-%-help")
		t:eq(err.text:find("root example", 1, true), nil)
	end)

	t:test("auto help/version appear under Common options when user defines groups", function()
		local cli = require("wardlib.tools.cli")
		local p = cli.new({
			name = "mytool",
			summary = "Groups",
			options = {
				{
					id = "output",
					long = "output",
					kind = "value",
					metavar = "FILE",
					help = "Output file",
					group = "Output options",
				},
			},
		}, { auto_version = true })

		local ok, err = p:parse({ [0] = "mytool", "--help" })
		t:eq(ok, false)
		t:eq(err.code, "help")
		t:match(err.text, "Output options:")
		t:match(err.text, "Common options:")
		t:match(err.text, "%-%-help")
		t:match(err.text, "%-%-version")
		-- No plain "Options:" header should be emitted in this case
		t:eq(err.text:find("\nOptions:\n", 1, true), nil)
	end)

	t:test("--no-dry-run clears negatable flag", function()
		local p = make_parser()
		local ok, out = p:parse({ [0] = "mytool", "--dry-run", "--no-dry-run", "in.txt" })
		t:eq(ok, true)
		t:eq(out.values.dry_run, false)
	end)

	t:test("repeatable=false errors on repeated value option", function()
		local cli = require("wardlib.tools.cli")
		local p = cli.new({
			name = "mytool",
			options = {
				{ id = "config", long = "config", kind = "value", repeatable = false },
			},
			positionals = { { id = "input", metavar = "INPUT", kind = "value", required = true } },
		})
		local ok, err = p:parse({ [0] = "mytool", "--config", "a", "--config", "b", "in.txt" })
		t:eq(ok, false)
		t:eq(err.code, "option_repeated")
	end)

	t:test("max_count caps count options", function()
		local cli = require("wardlib.tools.cli")
		local p = cli.new({
			name = "mytool",
			options = { { id = "verbose", short = "v", long = "verbose", kind = "count", max_count = 2 } },
			positionals = { { id = "input", metavar = "INPUT", kind = "value", required = true } },
		})
		local ok, err = p:parse({ [0] = "mytool", "-vvv", "in.txt" })
		t:eq(ok, false)
		t:eq(err.code, "too_many_occurrences")
	end)

	t:test("constraints.mutex enforces mutual exclusion", function()
		local cli = require("wardlib.tools.cli")
		local p = cli.new({
			name = "mytool",
			options = {
				{ id = "a", long = "a", kind = "flag" },
				{ id = "b", long = "b", kind = "flag" },
			},
			constraints = { mutex = { { "a", "b" } } },
		})
		local ok, err = p:parse({ [0] = "mytool", "--a", "--b" })
		t:eq(ok, false)
		t:eq(err.code, "mutually_exclusive")
	end)

	t:test("constraints.one_of requires at least one option", function()
		local cli = require("wardlib.tools.cli")
		local p = cli.new({
			name = "mytool",
			options = {
				{ id = "a", long = "a", kind = "flag" },
				{ id = "b", long = "b", kind = "flag" },
			},
			constraints = { one_of = { { "a", "b" } } },
		})
		local ok, err = p:parse({ [0] = "mytool" })
		t:eq(ok, false)
		t:eq(err.code, "missing_one_of")
	end)

	t:test("unknown long option suggests closest match", function()
		local p = make_parser()
		local ok, err = p:parse({ [0] = "mytool", "--verboes", "in.txt" })
		t:eq(ok, false)
		t:eq(err.code, "unknown_option")
		t:match(err.text, "did you mean %-%-verbose")
	end)

	t:test("unknown command suggests closest match", function()
		local cli = require("wardlib.tools.cli")
		local p = cli.new({
			name = "mytool",
			subcommands = { { name = "run", summary = "Run", options = {}, positionals = {} } },
		})
		local ok, err = p:parse({ [0] = "mytool", "rn" })
		t:eq(ok, false)
		t:eq(err.code, "unknown_command")
		t:match(err.text, "did you mean 'run'%?")
	end)

	t:test("custom validator rejects invalid option value", function()
		local cli = require("wardlib.tools.cli")
		local p = cli.new({
			name = "mytool",
			options = {
				{
					id = "jobs",
					long = "jobs",
					kind = "value",
					type = "int",
					validate = function(v) return v > 0, "must be > 0" end,
				},
			},
			positionals = { { id = "input", metavar = "INPUT", kind = "value", required = true } },
		})
		local ok, err = p:parse({ [0] = "mytool", "--jobs", "0", "in.txt" })
		t:eq(ok, false)
		t:eq(err.code, "invalid_value")
		t:match(err.text, "must be > 0")
	end)

	t:test("custom validator rejects invalid positional", function()
		local cli = require("wardlib.tools.cli")
		local p = cli.new({
			name = "mytool",
			positionals = {
				{
					id = "input",
					metavar = "INPUT",
					kind = "value",
					required = true,
					validate = function(v)
						if tostring(v):match("%.txt$") then return true end
						return false, "must end with .txt"
					end,
				},
			},
		})
		local ok, err = p:parse({ [0] = "mytool", "in.bin" })
		t:eq(ok, false)
		t:eq(err.code, "invalid_value")
		t:match(err.text, "must end with %.txt")
	end)

	return t
end
