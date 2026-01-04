---@diagnostic disable: duplicate-set-field

-- Tinytest suite for tools.with
--
-- This suite mocks ward.process used by tools.with:
--   * ward.process (push_middleware, pop_middleware)
--
-- It asserts that middleware scoping is balanced and that argv prefix middleware
-- behaves as expected.

return function(tinytest)
	local t = tinytest.new({ name = "tools.with" })

	local MODULE_CANDIDATES = { "tools.with" }

	local preload_orig = {
		["ward.process"] = package.preload["ward.process"],
	}

	local loaded_orig = {
		["ward.process"] = package.loaded["ward.process"],
	}

	for _, name in ipairs(MODULE_CANDIDATES) do
		loaded_orig[name] = package.loaded[name]
	end

	local stack = {}

	local function reset_stack()
		stack = {}
	end

	local function install_mocks()
		package.preload["ward.process"] = function()
			return {
				push_middleware = function(mw)
					stack[#stack + 1] = mw
				end,
				pop_middleware = function()
					stack[#stack] = nil
				end,
			}
		end

		package.loaded["ward.process"] = nil
		for _, name in ipairs(MODULE_CANDIDATES) do
			package.loaded[name] = nil
		end
	end

	local function restore_originals()
		package.preload["ward.process"] = preload_orig["ward.process"]
		package.loaded["ward.process"] = loaded_orig["ward.process"]
		for _, name in ipairs(MODULE_CANDIDATES) do
			package.loaded[name] = loaded_orig[name]
		end
	end

	local function load_module()
		local errs = {}
		for _, name in ipairs(MODULE_CANDIDATES) do
			local ok, mod = pcall(require, name)
			if ok and type(mod) == "table" then
				return mod
			end
			errs[#errs + 1] = name .. ": " .. tostring(mod)
		end
		t:ok(false, "failed to require tools.with. Tried:\n" .. table.concat(errs, "\n"))
	end

	local function throws(fn)
		local ok = pcall(fn)
		t:falsy(ok)
	end

	t:before_all(function()
		install_mocks()
	end)

	t:after_all(function()
		restore_originals()
	end)

	t:before_each(function()
		reset_stack()
		package.loaded["ward.process"] = nil
		for _, name in ipairs(MODULE_CANDIDATES) do
			package.loaded[name] = nil
		end
	end)

	-- -------------------------
	-- Tests
	-- -------------------------

	t:test("_as_argv supports string", function()
		local w = load_module()
		local argv = w._as_argv("sudo")
		t:eq(#argv, 1)
		t:eq(argv[1], "sudo")
	end)

	t:test("_as_argv supports argv array", function()
		local w = load_module()
		local argv = w._as_argv({ "sudo", "-n" })
		t:deep_eq(argv, { "sudo", "-n" })
	end)

	t:test("_as_argv supports cmd-like shapes", function()
		local w = load_module()
		t:eq(w._as_argv({ argv = { "sudo" } })[1], "sudo")
		t:eq(w._as_argv({ spec = { argv = { "sudo" } } })[1], "sudo")
		t:eq(w._as_argv({ _spec = { argv = { "sudo" } } })[1], "sudo")
	end)

	t:test("_as_argv rejects unsupported types", function()
		local w = load_module()
		throws(function()
			w._as_argv(123)
		end)
	end)

	t:test("middleware.prefix prefixes argv (and sep)", function()
		local w = load_module()
		local mw = w.middleware.prefix({ "sudo", "-n" }, { sep = "--" })
		local spec = { argv = { "ls", "-la" } }
		local out = mw(spec)
		t:deep_eq(out.argv, { "sudo", "-n", "--", "ls", "-la" })
	end)

	t:test("middleware.prefix is no-op for invalid spec", function()
		local w = load_module()
		local mw = w.middleware.prefix({ "sudo" })
		t:eq(mw(nil), nil)
		t:deep_eq(mw({}), {})
		t:deep_eq(mw({ argv = {} }), { argv = {} })
	end)

	t:test("scope pushes/pops on success", function()
		local w = load_module()
		w.scope(function(s)
			return s
		end, function()
			t:eq(#stack, 1)
		end)
		t:eq(#stack, 0)
	end)

	t:test("scope pushes/pops on error", function()
		local w = load_module()
		local ok = pcall(function()
			w.scope(function(s)
				return s
			end, function()
				t:eq(#stack, 1)
				error("boom")
			end)
		end)
		t:falsy(ok)
		t:eq(#stack, 0)
	end)

	t:test("with(prefix, cmd) wraps method calls under scope", function()
		local w = load_module()
		local cmd = {
			run = function(self)
				return #stack
			end,
		}

		local wrapped = w.with({ "sudo" }, cmd)
		t:eq(wrapped:run(), 1)
		t:eq(#stack, 0)
	end)

	t:test("with(prefix, fn) scopes block", function()
		local w = load_module()
		w.with({ "sudo" }, function()
			t:eq(#stack, 1)
		end)
		t:eq(#stack, 0)
	end)

	return t
end
