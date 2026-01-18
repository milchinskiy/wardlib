-- wardlib.tools.dotfiles
--
-- Dotfiles management as an ordered list of explicit step records.
--
-- Public API (recommended):
--   local dotfiles = require("wardlib.tools.dotfiles")
--   local def = dotfiles.define("My preset", {
--     description = "...",
--     steps = {
--       dotfiles.content(".config/git/config", "..."),
--       dotfiles.link(".config/fish", "~/.dotfiles/fish", { recursive = true }),
--       dotfiles.custom(nil, function(base) ... end, { when = function(base) return true end }),
--     },
--   })
--   def:apply("/home/alex", { force = true })
--   def:revert("/home/alex")
--
-- Notes:
--  * Ordering is always preserved (steps are applied in array order).
--  * No backups / content hashing / planning yet (by design).

local validate = require("wardlib.util.validate")

local env = require("ward.env")
local fs = require("ward.fs")
local is_windows = require("ward.host.platform").is_windows

local json = require("ward.convert.json")

local M = {}

---@class DotfilesDefinition
---@field name string
---@field description string?
---@field steps table[]
---@field defaults table?
local Definition = {}
Definition.__index = Definition

-- =========================
-- Helpers
-- =========================

local function normalize_sep(p)
	if is_windows() then return (p:gsub("/", "\\")) end
	return (p:gsub("\\", "/"))
end

local function expand_tilde(p)
	if type(p) ~= "string" then return p end
	if p == "~" then return env.get("HOME") or p end
	if p:sub(1, 2) == "~/" or p:sub(1, 2) == "~\\" then
		local home = env.get("HOME")
		if not home or home == "" then return p end
		return fs.join(home, p:sub(3))
	end
	return p
end

local function is_abs(p)
	if type(p) ~= "string" or p == "" then return false end
	p = normalize_sep(p)
	if p:sub(1, 1) == "/" or p:sub(1, 1) == "\\" then return true end
	-- Windows drive
	if p:match("^%a:[/\\]") then return true end
	return false
end

local function has_parent_traversal(rel)
	rel = normalize_sep(rel)
	if rel == ".." or rel:sub(1, 3) == "../" then return true end
	if rel:find("/../", 1, true) then return true end
	if rel:sub(-3) == "/.." then return true end
	return false
end

local function validate_rel_path(rel)
	validate.non_empty_string(rel, "path")
	if is_abs(rel) then error("dotfiles: path must be relative: " .. rel, 3) end
	if has_parent_traversal(rel) then error("dotfiles: refusing path traversal: " .. rel, 3) end
end

local function ensure_parent_dir(path)
	local parent = fs.dirname(path)
	if parent and parent ~= "" then fs.mkdir(parent, { recursive = true }) end
end

local function read_text(path) return fs.read(path, { mode = "text" }) end

local function ensure_table(v, label)
	if v == nil then return {} end
	if type(v) ~= "table" then error(label .. " must be table", 3) end
	return v
end

local function now_iso() return require("ward.time").now():rfc3339() end

local function manifest_path_for(base, opts)
	opts = opts or {}
	if opts.manifest_path then return tostring(opts.manifest_path) end
	return fs.join(base, ".ward", "dotfiles-manifest.json")
end

local function record_prev_state(abs)
	if not fs.is_exists(abs) then return { kind = "absent" } end

	if fs.is_symlink(abs) then return { kind = "symlink", target = fs.readlink(abs) } end

	if fs.is_dir(abs) then return { kind = "dir" } end

	return { kind = "file", content = read_text(abs) }
end

local function safe_unlink(abs)
	-- Remove a file or symlink without following.
	if fs.is_dir(abs) and (not fs.is_symlink(abs)) then
		-- Directory removal should be explicit and conservative.
		return false, "refusing to unlink directory"
	end
	fs.unlink(abs, { force = true })
	return true
end

local function try_rmdir_empty(abs)
	if not fs.is_dir(abs) or fs.is_symlink(abs) then return true end
	local items = fs.list(abs, { recursive = false })
	if #items > 0 then return false end
	fs.rm(abs, { recursive = false, force = true })
	return true
end

-- =========================
-- Step constructors
-- =========================

---@class DotfilesWhen
---@field when fun(base: string): boolean

---@class DotfilesStep
---@field _kind string

---@param rel string
---@param content string|fun(base: string, abs: string): string
---@param opts table|nil
---@return DotfilesStep
function M.content(rel, content, opts)
	validate_rel_path(rel)
	if type(content) ~= "string" and type(content) ~= "function" then
		error("dotfiles.content: content must be string or function", 2)
	end
	return {
		_kind = "content",
		rel = rel,
		content = content,
		opts = opts or {},
	}
end

---@param rel string
---@param source string
---@param opts table|nil
---@return DotfilesStep
function M.link(rel, source, opts)
	validate_rel_path(rel)
	validate.non_empty_string(source, "source")
	return {
		_kind = "link",
		rel = rel,
		source = source,
		opts = opts or {},
	}
end

---@param rel string|nil
---@param fn fun(base: string, abs: string|nil): any
---@param opts table|nil
---@return DotfilesStep
function M.custom(rel, fn, opts)
	if rel ~= nil then validate_rel_path(rel) end
	if type(fn) ~= "function" then error("dotfiles.custom: fn must be function", 2) end
	return {
		_kind = "custom",
		rel = rel,
		fn = fn,
		opts = opts or {},
	}
end

---@param prefix string|nil
---@param def DotfilesDefinition|table
---@param opts table|nil
---@return DotfilesStep
function M.include(prefix, def, opts)
	if prefix ~= nil then validate_rel_path(prefix) end
	if type(def) ~= "table" then error("dotfiles.include: def must be DotfilesDefinition or define() meta", 2) end
	return {
		_kind = "include",
		prefix = prefix,
		def = def,
		opts = opts or {},
	}
end

---@param name string
---@param steps table
---@param opts table|nil
---@return DotfilesStep
function M.group(name, steps, opts)
	validate.non_empty_string(name, "group name")
	if type(steps) ~= "table" then error("dotfiles.group: steps must be table", 2) end
	return {
		_kind = "group",
		name = name,
		steps = steps,
		opts = opts or {},
	}
end

---@param predicate fun(base: string): boolean
---@param message string
---@param opts table|nil
---@return DotfilesStep
function M.assert(predicate, message, opts)
	if type(predicate) ~= "function" then error("dotfiles.assert: predicate must be function", 2) end
	validate.non_empty_string(message, "message")
	return {
		_kind = "assert",
		predicate = predicate,
		message = message,
		opts = opts or {},
	}
end

-- =========================
-- Definition
-- =========================

local function normalize_definition(def)
	-- Accept:
	--   * DotfilesDefinition
	--   * define() meta table: { name?, description?, defaults?, steps = {...} }
	if getmetatable(def) == Definition then return def end

	local name = def.name or "dotfiles"
	local meta = def
	if meta.steps == nil then error("dotfiles: include expects a DotfilesDefinition or meta table with steps", 3) end
	return M.define(name, meta)
end

---@param name string
---@param meta table
---@return DotfilesDefinition
function M.define(name, meta)
	validate.non_empty_string(name, "name")
	meta = ensure_table(meta, "meta")
	local steps = ensure_table(meta.steps, "steps")
	if #steps == 0 then error("dotfiles.define: steps must be a non-empty array", 2) end

	local self = setmetatable({
		name = name,
		description = meta.description,
		defaults = meta.defaults,
		steps = steps,
	}, Definition)

	return self
end

-- =========================
-- Apply implementation
-- =========================

local function eval_when(base, opts)
	opts = opts or {}
	local w = opts.when or opts.conditions
	if w == nil then return true end
	if type(w) ~= "function" then error("dotfiles: when/conditions must be function", 3) end
	local ok, res = pcall(w, base)
	if not ok then error("dotfiles: when/conditions failed: " .. tostring(res), 3) end
	return not not res
end

local function apply_content(base, abs, step, apply_opts, manifest)
	local prev = record_prev_state(abs)
	local force = apply_opts.force == true

	if prev.kind ~= "absent" then
		if prev.kind == "dir" then error("dotfiles: refusing to write file over directory: " .. abs, 3) end
		if not force then error("dotfiles: destination exists (use force=true): " .. abs, 3) end
		-- Never write through an existing symlink.
		if prev.kind == "symlink" then
			local ok, err = safe_unlink(abs)
			if not ok then error("dotfiles: cannot replace symlink: " .. abs .. ": " .. tostring(err), 3) end
		end
	end

	ensure_parent_dir(abs)

	local content = step.content
	local rendered
	if type(content) == "function" then
		rendered = content(base, abs)
	else
		rendered = content
	end
	if type(rendered) ~= "string" then error("dotfiles.content: content function must return string", 3) end

	fs.write(abs, rendered, { mode = "overwrite" })

	manifest.entries[#manifest.entries + 1] = {
		kind = "content",
		path = abs,
		prev = prev,
	}
end

local function ensure_dest_dir(abs_dir, apply_opts, manifest)
	if fs.is_exists(abs_dir) then
		if fs.is_dir(abs_dir) and not fs.is_symlink(abs_dir) then return end
		if apply_opts.force ~= true then
			error("dotfiles: destination exists and is not a directory (use force=true): " .. abs_dir, 3)
		end
		local prev = record_prev_state(abs_dir)
		-- Avoid following symlink.
		if fs.is_symlink(abs_dir) then
			local ok, err = safe_unlink(abs_dir)
			if not ok then error("dotfiles: cannot replace symlink: " .. abs_dir .. ": " .. tostring(err), 3) end
		else
			-- file
			fs.unlink(abs_dir, { force = true })
		end
		fs.mkdir(abs_dir, { recursive = true })
		manifest.entries[#manifest.entries + 1] = {
			kind = "dir",
			path = abs_dir,
			prev = prev,
		}
		return
	end

	fs.mkdir(abs_dir, { recursive = true })
	manifest.entries[#manifest.entries + 1] = {
		kind = "dir",
		path = abs_dir,
		prev = { kind = "absent" },
	}
end

local function apply_symlink(base, abs, step, apply_opts, manifest)
	local opts = step.opts or {}
	local force = apply_opts.force == true

	local source = expand_tilde(step.source)
	source = normalize_sep(source)

	local prev = record_prev_state(abs)

	local function replace_allowed(prev_kind)
		if prev_kind == "absent" then return true end
		if prev_kind == "symlink" then return opts.replace_symlink ~= false end
		if prev_kind == "file" then return opts.replace_file ~= false end
		if prev_kind == "dir" then return opts.replace_dir == true end
		return false
	end

	if prev.kind ~= "absent" then
		if not force then error("dotfiles: destination exists (use force=true): " .. abs, 3) end
		if not replace_allowed(prev.kind) then
			error("dotfiles: refusing to replace existing " .. prev.kind .. ": " .. abs, 3)
		end
		if prev.kind == "dir" then
			-- Conservative: only allow replacing empty directories.
			local items = fs.list(abs, { recursive = false })
			if #items > 0 then error("dotfiles: refusing to replace non-empty directory: " .. abs, 3) end
			fs.rm(abs, { recursive = false, force = true })
		else
			-- file or symlink
			local ok, err = safe_unlink(abs)
			if not ok then error("dotfiles: cannot unlink: " .. abs .. ": " .. tostring(err), 3) end
		end
	end

	if opts.follow_dest_symlink == true and fs.is_symlink(abs) then
		error("dotfiles: follow_dest_symlink cannot be used when destination is a symlink", 3)
	end

	ensure_parent_dir(abs)
	fs.symlink(source, abs)

	manifest.entries[#manifest.entries + 1] = {
		kind = "symlink",
		path = abs,
		source = source,
		prev = prev,
	}
end

local function apply_link_recursive(base, abs_dir, step, apply_opts, manifest)
	local source_root = expand_tilde(step.source)
	source_root = normalize_sep(source_root)

	if not fs.is_dir(source_root) then
		error("dotfiles: recursive link source must be a directory: " .. source_root, 3)
	end

	ensure_dest_dir(abs_dir, apply_opts, manifest)

	local all = fs.list(source_root, { recursive = true })
	table.sort(all)

	local function rel_from_root(p)
		p = normalize_sep(p)
		local root = normalize_sep(source_root)
		if p == root then return "" end
		if p:sub(1, #root) ~= root then return nil end
		local rest = p:sub(#root + 1)
		if rest:sub(1, 1) == "/" or rest:sub(1, 1) == "\\" then rest = rest:sub(2) end
		return rest
	end

	for _, src in ipairs(all) do
		local rel = rel_from_root(src)
		if rel and rel ~= "" then
			local dest = fs.join(abs_dir, rel)
			if fs.is_dir(src) and not fs.is_symlink(src) then
				ensure_dest_dir(dest, apply_opts, manifest)
			else
				apply_symlink(base, dest, {
					_kind = "link",
					rel = step.rel,
					source = src,
					opts = step.opts,
				}, apply_opts, manifest)
			end
		end
	end
end

local function apply_link(base, abs, step, apply_opts, manifest)
	local opts = step.opts or {}
	if opts.recursive == true then
		apply_link_recursive(base, abs, step, apply_opts, manifest)
		return
	end
	apply_symlink(base, abs, step, apply_opts, manifest)
end

local function apply_steps(owner_def, base, steps, apply_opts, manifest)
	for i, step in ipairs(steps) do
		if type(step) == "table" and getmetatable(step) == Definition then
			-- Nested definition applied in place (single manifest).
			apply_steps(step, base, step.steps, apply_opts, manifest)
		else
			if type(step) ~= "table" or type(step._kind) ~= "string" then
				error("dotfiles: invalid step at index " .. tostring(i), 3)
			end

			local kind = step._kind

			if kind == "content" then
				if eval_when(base, step.opts) then
					local abs = fs.join(base, step.rel)
					apply_content(base, abs, step, apply_opts, manifest)
				end
			elseif kind == "link" then
				if eval_when(base, step.opts) then
					local abs = fs.join(base, step.rel)
					apply_link(base, abs, step, apply_opts, manifest)
				end
			elseif kind == "custom" then
				if eval_when(base, step.opts) then
					local abs = nil
					if step.rel then abs = fs.join(base, step.rel) end
					local ok, res = pcall(step.fn, base, abs)
					if not ok then error("dotfiles.custom: failed: " .. tostring(res), 3) end

					if res == nil then
						manifest.entries[#manifest.entries + 1] = { kind = "exec", note = "custom", rel = step.rel }
					elseif type(res) == "string" then
						if not abs then error("dotfiles.custom: string result requires a path", 3) end
						apply_content(base, abs, { content = res }, apply_opts, manifest)
					elseif type(res) == "table" then
						local nested
						if getmetatable(res) == Definition then
							nested = res
						elseif res.steps then
							nested = normalize_definition(res)
						else
							-- treat as steps array
							nested = M.define("custom", { steps = res })
						end

						if abs then
							apply_steps(nested, abs, nested.steps, apply_opts, manifest)
						else
							apply_steps(nested, base, nested.steps, apply_opts, manifest)
						end
					else
						error("dotfiles.custom: unsupported return type: " .. type(res), 3)
					end
				end
			elseif kind == "include" then
				if eval_when(base, step.opts) then
					local nested = normalize_definition(step.def)
					local target = base
					if step.prefix then target = fs.join(base, step.prefix) end
					apply_steps(nested, target, nested.steps, apply_opts, manifest)
				end
			elseif kind == "group" then
				if eval_when(base, step.opts) then apply_steps(owner_def, base, step.steps, apply_opts, manifest) end
			elseif kind == "assert" then
				if eval_when(base, step.opts) then
					local ok, res = pcall(step.predicate, base)
					if not ok then error("dotfiles.assert: predicate failed: " .. tostring(res), 3) end
					if not res then error(step.message, 3) end
					manifest.entries[#manifest.entries + 1] = { kind = "assert", message = step.message }
				end
			else
				error("dotfiles: unknown step kind: " .. tostring(kind), 3)
			end
		end
	end
end

function Definition:apply(base, opts)
	validate.non_empty_string(base, "base")
	opts = opts or {}

	local manifest = {
		name = self.name,
		description = self.description,
		applied_at = now_iso(),
		base = base,
		entries = {},
	}

	apply_steps(self, base, self.steps, opts, manifest)

	local mp = manifest_path_for(base, opts)
	ensure_parent_dir(mp)
	fs.write(mp, json.encode(manifest, { pretty = true, indent = 2 }), { mode = "overwrite" })

	return manifest
end

-- =========================
-- Revert implementation
-- =========================

local function restore_prev(abs, prev)
	if prev.kind == "absent" then
		if fs.is_exists(abs) then
			if fs.is_dir(abs) and not fs.is_symlink(abs) then
				-- Only remove if empty.
				return try_rmdir_empty(abs)
			end
			safe_unlink(abs)
		end
		return true
	end

	if prev.kind == "symlink" then
		if prev.target == nil or prev.target == "" then
			-- Dangling previous symlink target unknown; best-effort: remove current path.
			if fs.is_exists(abs) then
				if fs.is_dir(abs) and not fs.is_symlink(abs) then return try_rmdir_empty(abs) end
				safe_unlink(abs)
			end
			return true
		end
		if fs.is_exists(abs) then
			if fs.is_dir(abs) and not fs.is_symlink(abs) then
				-- Refuse to replace dir during revert.
				return false
			end
			safe_unlink(abs)
		end
		ensure_parent_dir(abs)
		fs.symlink(prev.target, abs)
		return true
	end

	if prev.kind == "file" then
		if fs.is_exists(abs) and fs.is_dir(abs) and not fs.is_symlink(abs) then return false end
		if fs.is_symlink(abs) then safe_unlink(abs) end
		ensure_parent_dir(abs)
		fs.write(abs, prev.content or "", { mode = "overwrite" })
		return true
	end

	if prev.kind == "dir" then
		-- Best-effort: ensure dir exists.
		if fs.is_exists(abs) then
			if fs.is_dir(abs) and not fs.is_symlink(abs) then return true end
			if fs.is_symlink(abs) then safe_unlink(abs) end
			if fs.is_dir(abs) and fs.is_symlink(abs) then safe_unlink(abs) end
			if fs.is_exists(abs) and not fs.is_dir(abs) then safe_unlink(abs) end
		end
		fs.mkdir(abs, { recursive = true })
		return true
	end

	return false
end

function Definition:revert(base, opts)
	validate.non_empty_string(base, "base")
	opts = opts or {}

	local mp = manifest_path_for(base, opts)
	if not fs.is_exists(mp) then error("dotfiles: manifest not found: " .. mp, 2) end

	local manifest = json.decode(read_text(mp))
	if type(manifest) ~= "table" or type(manifest.entries) ~= "table" then
		error("dotfiles: invalid manifest: " .. mp, 2)
	end

	-- Restore in reverse order to minimize dependency issues.
	for i = #manifest.entries, 1, -1 do
		local e = manifest.entries[i]
		if type(e) == "table" and e.path and e.prev then restore_prev(e.path, e.prev) end
	end

	-- Remove manifest directory if empty.
	safe_unlink(mp)
	local ward_dir = fs.dirname(mp)
	if ward_dir then try_rmdir_empty(ward_dir) end

	return true
end

return M
