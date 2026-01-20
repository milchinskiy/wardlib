---@diagnostic disable: duplicate-set-field

-- Tinytest suite for tools.out
--
-- Mocks:
--   * ward.helpers.string (trim)
--   * ward.convert.json/yaml/toml/ini (decode)

return function(tinytest)
	local t = tinytest.new({ name = "tools.out" })

	local MODULE = "wardlib.tools.out"

	local preload_orig = {
		["ward.helpers.string"] = package.preload["ward.helpers.string"],
		["ward.convert.json"] = package.preload["ward.convert.json"],
		["ward.convert.yaml"] = package.preload["ward.convert.yaml"],
		["ward.convert.toml"] = package.preload["ward.convert.toml"],
		["ward.convert.ini"] = package.preload["ward.convert.ini"],
	}
	local loaded_orig = {
		["ward.helpers.string"] = package.loaded["ward.helpers.string"],
		["ward.convert.json"] = package.loaded["ward.convert.json"],
		["ward.convert.yaml"] = package.loaded["ward.convert.yaml"],
		["ward.convert.toml"] = package.loaded["ward.convert.toml"],
		["ward.convert.ini"] = package.loaded["ward.convert.ini"],
		[MODULE] = package.loaded[MODULE],
	}

	local function install_mocks(opts)
		opts = opts or {}
		package.preload["ward.helpers.string"] = function()
			return {
				trim = function(s)
					return (tostring(s):gsub("^%s+", ""):gsub("%s+$", ""))
				end,
			}
		end

		local function dec(v)
			return function(s)
				if opts.decode_error then error("decode failed") end
				return v or { decoded = true, input = s }
			end
		end
		package.preload["ward.convert.json"] = function() return { decode = dec(opts.json_value) } end
		package.preload["ward.convert.yaml"] = function() return { decode = dec(opts.yaml_value) } end
		package.preload["ward.convert.toml"] = function() return { decode = dec(opts.toml_value) } end
		package.preload["ward.convert.ini"] = function() return { decode = dec(opts.ini_value) } end

		package.loaded["ward.helpers.string"] = nil
		package.loaded["ward.convert.json"] = nil
		package.loaded["ward.convert.yaml"] = nil
		package.loaded["ward.convert.toml"] = nil
		package.loaded["ward.convert.ini"] = nil
		package.loaded[MODULE] = nil
	end

	local function restore_originals()
		package.preload["ward.helpers.string"] = preload_orig["ward.helpers.string"]
		package.preload["ward.convert.json"] = preload_orig["ward.convert.json"]
		package.preload["ward.convert.yaml"] = preload_orig["ward.convert.yaml"]
		package.preload["ward.convert.toml"] = preload_orig["ward.convert.toml"]
		package.preload["ward.convert.ini"] = preload_orig["ward.convert.ini"]

		package.loaded["ward.helpers.string"] = loaded_orig["ward.helpers.string"]
		package.loaded["ward.convert.json"] = loaded_orig["ward.convert.json"]
		package.loaded["ward.convert.yaml"] = loaded_orig["ward.convert.yaml"]
		package.loaded["ward.convert.toml"] = loaded_orig["ward.convert.toml"]
		package.loaded["ward.convert.ini"] = loaded_orig["ward.convert.ini"]
		package.loaded[MODULE] = nil
	end

	local function mod() return require(MODULE) end

	local function fake_cmd(res, calls)
		calls = calls or { n = 0 }
		return {
			output = function()
				calls.n = calls.n + 1
				return res
			end,
			_calls = calls,
		}
	end

	-- --- tests ---

	t:test("cmd(): caches :output() result", function()
		install_mocks()
		local out = mod()
		local calls = { n = 0 }
		local cmd = fake_cmd({ ok = true, stdout = "a\n" }, calls)

		local w = out.cmd(cmd)
		t:eq(w:line(), "a")
		-- second terminal call must reuse cached CmdResult
		t:eq(w:text(), "a\n")
		t:eq(calls.n, 1)
		restore_originals()
	end)

	t:test("res(): uses provided result without executing", function()
		install_mocks()
		local out = mod()
		local v = out.res({ ok = true, stdout = "hello" }):text()
		t:eq(v, "hello")
		restore_originals()
	end)

	t:test("trim()+line(): trims and enforces single line", function()
		install_mocks()
		local out = mod()
		local v = out.res({ ok = true, stdout = "  x  \n" }):trim():line()
		t:eq(v, "x")
		restore_originals()
	end)

	t:test("normalize_newlines(): converts CRLF", function()
		install_mocks()
		local out = mod()
		local ls = out.res({ ok = true, stdout = "a\r\nb\r\n" }):lines()
		t:eq(#ls, 2)
		t:eq(ls[1], "a")
		t:eq(ls[2], "b")
		restore_originals()
	end)

	t:test("stderr(): selects stderr stream", function()
		install_mocks()
		local out = mod()
		local v = out.res({ ok = true, stdout = "out", stderr = "err" }):stderr():text()
		t:eq(v, "err")
		restore_originals()
	end)

	t:test("ok() failure: throws with label and preview", function()
		install_mocks()
		local out = mod()
		local ok, err = pcall(function()
			out.res({ ok = false, code = 2, signal = nil, stdout = "", stderr = "boom" })
				:label("mycmd")
				:text()
		end)
		t:eq(ok, false)
		t:contains(err, "mycmd failed")
		t:contains(err, "code=2")
		t:contains(err, "stderr preview")
		t:contains(err, "boom")
		restore_originals()
	end)

	t:test("allow_fail(): does not throw on ok=false", function()
		install_mocks()
		local out = mod()
		local v = out.res({ ok = false, code = 1, stdout = "x" }):allow_fail():text()
		t:eq(v, "x")
		restore_originals()
	end)

	t:test("stdout nil: errors with hint", function()
		install_mocks()
		local out = mod()
		local ok, err = pcall(function() out.res({ ok = true, stdout = nil }):text() end)
		t:eq(ok, false)
		t:contains(err, "stdout is nil")
		t:contains(err, ":output()")
		restore_originals()
	end)

	t:test("json(): decodes using ward.convert.json.decode", function()
		install_mocks({ json_value = { a = 1 } })
		local out = mod()
		local v = out.res({ ok = true, stdout = "{\"a\":1}" }):json()
		t:eq(v.a, 1)
		restore_originals()
	end)

	t:test("json(): decode errors include preview", function()
		install_mocks({ decode_error = true })
		local out = mod()
		local ok, err = pcall(function()
			out.res({ ok = true, stdout = "{bad json" }):label("jsoncmd"):json()
		end)
		t:eq(ok, false)
		t:contains(err, "jsoncmd")
		t:contains(err, "failed to decode json")
		t:contains(err, "stdout preview")
		t:contains(err, "{bad json")
		restore_originals()
	end)

	return t
end
