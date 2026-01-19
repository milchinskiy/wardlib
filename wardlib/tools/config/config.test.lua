local t = require("wardlib.test.tinytest").new({ name = "tools.config" })

local config = require("wardlib.tools.config")
local fs = require("ward.fs")

local root

t:before_each(function() root = fs.tempdir("wardlib-config") end)

t:after_each(function()
	if root then
		fs.rm(root, { recursive = true, force = true })
		root = nil
	end
end)

local function path(...) return fs.join(root, ...) end

t:test("infer_format recognizes common extensions", function()
	t:eq(config.infer_format("a.json"), "json")
	t:eq(config.infer_format("a.yaml"), "yaml")
	t:eq(config.infer_format("a.yml"), "yaml")
	t:eq(config.infer_format("a.toml"), "toml")
	t:eq(config.infer_format("a.ini"), "ini")
	t:eq(config.infer_format("a.txt"), nil)
end)

t:test("write/read JSON roundtrip", function()
	local f = path("cfg.json")
	local wrote = config.write(f, { a = 1, b = { true, false } }, { pretty = true, mkdir = true })
	t:ok(wrote)
	local doc = config.read(f)
	t:eq(doc.a, 1)
	t:eq(doc.b[1], true)
	t:eq(doc.b[2], false)
end)

t:test("write_if_changed skips when identical", function()
	local f = path("x.json")
	config.write(f, { a = 1 }, { mkdir = true })
	local wrote2 = config.write(f, { a = 1 }, { write_if_changed = true })
	t:eq(wrote2, false)
end)

t:test("patch mutates in place by default", function()
	local f = path("p.json")
	config.write(f, { a = 1 }, { mkdir = true })
	config.patch(f, function(doc) doc.b = 2 end)
	local doc = config.read(f)
	t:eq(doc.a, 1)
	t:eq(doc.b, 2)
end)

t:test("patch can create missing file when allow_missing", function()
	local f = path("new.json")
	local doc = config.patch(f, function(d)
		d.enabled = true
		return d
	end, { allow_missing = true, mkdir = true })
	t:eq(doc.enabled, true)
	t:ok(fs.is_file(f))
end)

t:test("merge deep vs shallow", function()
	local base = { a = { x = 1, y = 1 }, k = 1 }
	local overlay = { a = { y = 2 }, k = 2 }

	local d = config.merge(base, overlay, { mode = "deep" })
	t:eq(d.a.x, 1)
	t:eq(d.a.y, 2)
	t:eq(d.k, 2)

	local s = config.merge(base, overlay, { mode = "shallow" })
	t:eq(s.a.x, nil)
	t:eq(s.a.y, 2)
	t:eq(s.k, 2)
end)

return t
