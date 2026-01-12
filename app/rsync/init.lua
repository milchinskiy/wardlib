---@diagnostic disable: undefined-doc-name

-- rsync wrapper module
--
-- Thin wrappers around `rsync` that construct CLI invocations and return
-- `ward.process.cmd(...)` objects.

local _cmd = require("ward.process")
local validate = require("util.validate")
local ensure = require("tools.ensure")
local args_util = require("util.args")

---@class RsyncOpts
---@field archive boolean? `-a`
---@field compress boolean? `-z`
---@field verbose boolean? `-v`
---@field progress boolean? `--progress`
---@field delete boolean? `--delete`
---@field dry_run boolean? `--dry-run`
---@field checksum boolean? `--checksum`
---@field partial boolean? `--partial`
---@field excludes string[]? `--exclude <pattern>` repeated
---@field include string[]? `--include <pattern>` repeated
---@field rsh string? `-e <rsh>` (e.g. "ssh -p 2222 -i ~/.ssh/id_ed25519")
---@field extra string[]? Extra args appended before src/dest

---@class Rsync
---@field bin string
---@field sync fun(src: string|string[], dest: string, opts: RsyncOpts|nil): ward.Cmd
local Rsync = {
	bin = "rsync",
}

---@param args string[]
---@param opts RsyncOpts|nil
local function apply_opts(args, opts)
	opts = opts or {}
	if opts.archive then
		table.insert(args, "-a")
	end
	if opts.compress then
		table.insert(args, "-z")
	end
	if opts.verbose then
		table.insert(args, "-v")
	end
	if opts.progress then
		table.insert(args, "--progress")
	end
	if opts.delete then
		table.insert(args, "--delete")
	end
	if opts.dry_run then
		table.insert(args, "--dry-run")
	end
	if opts.checksum then
		table.insert(args, "--checksum")
	end
	if opts.partial then
		table.insert(args, "--partial")
	end
	if opts.rsh ~= nil then
		validate.non_empty_string(opts.rsh, "rsh")
		table.insert(args, "-e")
		table.insert(args, opts.rsh)
	end
	if opts.excludes ~= nil then
		assert(type(opts.excludes) == "table", "excludes must be an array")
		for _, p in ipairs(opts.excludes) do
			validate.non_empty_string(p, "exclude")
			table.insert(args, "--exclude")
			table.insert(args, p)
		end
	end
	if opts.include ~= nil then
		assert(type(opts.include) == "table", "include must be an array")
		for _, p in ipairs(opts.include) do
			validate.non_empty_string(p, "include")
			table.insert(args, "--include")
			table.insert(args, p)
		end
	end
	args_util.append_extra(args, opts.extra)
end

---Construct an rsync command.
---@param src string|string[]
---@param dest string
---@param opts RsyncOpts|nil
---@return ward.Cmd
function Rsync.sync(src, dest, opts)
	ensure.bin(Rsync.bin, { label = 'rsync binary' })
	validate.non_empty_string(dest, "dest")

	local sources = {}
	if type(src) == "string" then
		validate.non_empty_string(src, "src")
		sources = { src }
	elseif type(src) == "table" then
		assert(#src > 0, "src list must be non-empty")
		for _, s in ipairs(src) do
			validate.non_empty_string(s, "src")
			table.insert(sources, s)
		end
	else
		error("src must be string or string[]")
	end

	local args = { Rsync.bin }
	apply_opts(args, opts)
	for _, s in ipairs(sources) do
		table.insert(args, s)
	end
	table.insert(args, dest)
	return _cmd.cmd(table.unpack(args))
end

return {
	Rsync = Rsync,
}
