---@diagnostic disable: undefined-doc-name

-- rsync wrapper module
--
-- Thin wrappers around `rsync` that construct CLI invocations and return
-- `ward.process.cmd(...)` objects.

local _cmd = require("ward.process")
local validate = require("wardlib.util.validate")
local ensure = require("wardlib.tools.ensure")
local args_util = require("wardlib.util.args")

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
	args_util
		.parser(args, opts)
		:flag("archive", "-a")
		:flag("compress", "-z")
		:flag("verbose", "-v")
		:flag("progress", "--progress")
		:flag("delete", "--delete")
		:flag("dry_run", "--dry-run")
		:flag("checksum", "--checksum")
		:flag("partial", "--partial")
		:value_string("rsh", "-e")
		:repeatable("excludes", "--exclude")
		:repeatable("include", "--include")
		:extra()
end

---Construct an rsync command.
---@param src string|string[]
---@param dest string
---@param opts RsyncOpts|nil
---@return ward.Cmd
function Rsync.sync(src, dest, opts)
	ensure.bin(Rsync.bin, { label = "rsync binary" })
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
