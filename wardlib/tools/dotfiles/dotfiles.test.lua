local t = require("wardlib.test.tinytest").new({ name = "tools.dotfiles" })

local dotfiles = require("wardlib.tools.dotfiles")
local fs = require("ward.fs")

local root

t:before_each(function() root = fs.tempdir("wardlib-dotfiles") end)

t:after_each(function()
	if root then
		fs.rm(root, { recursive = true, force = true })
		root = nil
	end
end)

t:test("content writes a file and manifest is created", function()
	local def = dotfiles.define("basic", {
		steps = {
			dotfiles.content(".config/git/config", "hello"),
		},
	})

	def:apply(root)

	local p = fs.join(root, ".config", "git", "config")
	t:ok(fs.is_exists(p))
	t:eq(fs.read(p, { mode = "text" }), "hello")

	local mp = fs.join(root, ".ward", "dotfiles-manifest.json")
	t:ok(fs.is_exists(mp))
end)

t:test("content refuses to overwrite without force", function()
	local p = fs.join(root, "a")
	fs.write(p, "old", { mode = "overwrite" })

	local def = dotfiles.define("overwrite", {
		steps = {
			dotfiles.content("a", "new"),
		},
	})

	local ok = pcall(function() def:apply(root) end)
	t:falsy(ok)
end)

t:test("link creates symlink", function()
	local src = fs.join(root, "src.txt")
	fs.write(src, "x", { mode = "overwrite" })

	local def = dotfiles.define("link", {
		steps = {
			dotfiles.link("dst.txt", src),
		},
	})

	def:apply(root)

	local dst = fs.join(root, "dst.txt")
	t:ok(fs.is_symlink(dst))
	t:eq(fs.realpath(dst), src)
end)

t:test("recursive link mirrors tree as symlinks", function()
	local src_root = fs.join(root, "dot")
	fs.mkdir(src_root, { recursive = true })
	fs.mkdir(fs.join(src_root, "sub"), { recursive = true })
	fs.write(fs.join(src_root, "a.txt"), "a", { mode = "overwrite" })
	fs.write(fs.join(src_root, "sub", "b.txt"), "b", { mode = "overwrite" })

	local def = dotfiles.define("rec", {
		steps = {
			dotfiles.link(".config/my", src_root, { recursive = true }),
		},
	})

	def:apply(root)

	local a = fs.join(root, ".config", "my", "a.txt")
	local b = fs.join(root, ".config", "my", "sub", "b.txt")
	t:ok(fs.is_symlink(a))
	t:ok(fs.is_symlink(b))
	t:eq(fs.realpath(a), fs.join(src_root, "a.txt"))
	t:eq(fs.realpath(b), fs.join(src_root, "sub", "b.txt"))
end)

t:test("custom supports when gating", function()
	local ran = false
	local def = dotfiles.define("when", {
		steps = {
			dotfiles.custom(nil, function() ran = true end, {
				when = function() return false end,
			}),
		},
	})

	def:apply(root)
	t:falsy(ran)
end)

t:test("group preserves order", function()
	local def = dotfiles.define("order", {
		steps = {
			dotfiles.content("a", "x"),
			dotfiles.group("check", {
				dotfiles.custom(nil, function(base)
					local p = fs.join(base, "a")
					assert(fs.is_exists(p), "expected a to exist")
				end),
			}),
		},
	})

	def:apply(root)
	t:ok(true)
end)

t:test("include applies nested definition under prefix", function()
	local nested = dotfiles.define("nested", {
		steps = {
			dotfiles.content("x", "y"),
		},
	})

	local def = dotfiles.define("inc", {
		steps = {
			dotfiles.include("p", nested),
		},
	})

	def:apply(root)
	t:eq(fs.read(fs.join(root, "p", "x"), { mode = "text" }), "y")
end)

t:test("revert restores previous content", function()
	local p = fs.join(root, "a")
	fs.write(p, "old", { mode = "overwrite" })

	local def = dotfiles.define("revert", {
		steps = {
			dotfiles.content("a", "new"),
		},
	})

	def:apply(root, { force = true })
	t:eq(fs.read(p, { mode = "text" }), "new")

	def:revert(root)
	t:eq(fs.read(p, { mode = "text" }), "old")
end)

return t
