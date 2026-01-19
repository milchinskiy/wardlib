local t = require("wardlib.test.tinytest").new({ name = "tools.platform" })

local env = require("ward.env")
local fs = require("ward.fs")
local platform = require("wardlib.tools.platform")

local restore = {}

local function save_env(k) restore[k] = env.get(k) end

local function restore_env()
	for k, v in pairs(restore) do
		if v == nil then
			env.unset(k)
		else
			env.set(k, v)
		end
	end
	restore = {}
end

t:after_each(function() restore_env() end)

t:test("info includes host.platform info plus is_ci/home/tmpdir", function()
	save_env("CI")
	env.unset("CI")

	local info = platform.info()
	t:ok(type(info) == "table")
	t:ok(type(info.os) == "string" and #info.os > 0)
	t:ok(type(info.arch) == "string" and #info.arch > 0)
	t:eq(info.is_ci, false)
end)

t:test("is_ci detects common CI variables", function()
	save_env("CI")
	env.unset("CI")
	t:eq(platform.is_ci(), false)
	env.set("CI", "1")
	t:eq(platform.is_ci(), true)
	env.set("CI", "0")
	t:eq(platform.is_ci(), false)
end)

t:test("home prefers HOME then USERPROFILE", function()
	save_env("HOME")
	save_env("USERPROFILE")
	save_env("HOMEDRIVE")
	save_env("HOMEPATH")

	env.set("HOME", "/x")
	t:eq(platform.home(), "/x")

	env.unset("HOME")
	env.set("USERPROFILE", "C:\\Users\\me")
	t:eq(platform.home(), "C:\\Users\\me")
end)

t:test("parse_os_release parses key/value and quoted values", function()
	local text = [[
NAME="TestOS"
ID=test
VERSION_ID='1.2'
PRETTY_NAME="TestOS 1.2"
# comment
]]
	local m = platform.parse_os_release(text)
	t:eq(m.name, "TestOS")
	t:eq(m.id, "test")
	t:eq(m.version_id, "1.2")
	t:eq(m.pretty_name, "TestOS 1.2")
end)

t:test("linux.os_release can read from a provided path", function()
	local dir = fs.tempdir("wardlib-platform")
	local p = fs.join(dir, "os-release")
	fs.write(p, "ID=demo\nNAME=Demo\n", { mode = "overwrite" })

	local m = platform.linux.os_release({ path = p, force = true })
	t:eq(m.id, "demo")
	t:eq(m.name, "Demo")

	fs.rm(dir, { recursive = true, force = true })
end)

return t
