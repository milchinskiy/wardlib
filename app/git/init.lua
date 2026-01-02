---@diagnostic disable: undefined-doc-name

-- git wrapper module
--
-- Thin wrappers around `git` that construct CLI invocations and return
-- `ward.process.cmd(...)` objects.
--
-- This module intentionally does not parse output; consumers can decide how to
-- execute returned commands and interpret results.

local _cmd = require("ward.process")
local _env = require("ward.env")
local _fs = require("ward.fs")

---@class GitCommonOpts
---@field dir string? Run in repository directory via `-C <dir>`

---@class GitStatusOpts: GitCommonOpts
---@field short boolean? Add `-s`
---@field branch boolean? Add `-b` (works with `-s`)
---@field porcelain boolean? Add `--porcelain=v1`
---@field extra string[]? Extra args appended after options

---@class GitCloneOpts
---@field depth integer? Add `--depth <n>`
---@field branch string? Add `--branch <name>`
---@field recursive boolean? Add `--recursive`
---@field extra string[]? Extra args appended after options

---@class GitPushOpts: GitCommonOpts
---@field upstream boolean? Add `-u`
---@field extra string[]? Extra args appended after options

---@class Git
---@field bin string Executable name or path to `git`
---@field cmd fun(subcmd: string, argv: string[]|nil, opts: GitCommonOpts|nil): ward.Cmd
---@field status fun(opts: GitStatusOpts|nil): ward.Cmd
---@field root fun(opts: GitCommonOpts|nil): ward.Cmd
---@field is_repo fun(opts: GitCommonOpts|nil): ward.Cmd
---@field clone fun(url: string, dest: string|nil, opts: GitCloneOpts|nil): ward.Cmd
---@field push fun(remote: string|nil, branch: string|nil, opts: GitPushOpts|nil): ward.Cmd
local Git = {
	bin = "git",
}

---Validate binary
---@param bin string
local function validate_bin(bin)
	assert(type(bin) == "string" and #bin > 0, "git binary is not set")
	if bin:find("/", 1, true) then
		assert(_fs.is_exists(bin), string.format("git binary does not exist: %s", bin))
		assert(_fs.is_executable(bin), string.format("git binary is not executable: %s", bin))
	else
		assert(_env.is_in_path(bin), string.format("git binary is not in PATH: %s", bin))
	end
end

---Validate non-empty string and avoid flag-like accidental usage.
---@param value string
---@param label string
local function validate_not_flag(value, label)
	assert(type(value) == "string" and #value > 0, label .. " must be a non-empty string")
	assert(value:sub(1, 1) ~= "-", label .. " must not start with '-': " .. tostring(value))
end

---@param args string[]
---@param opts GitCommonOpts|nil
local function apply_common(args, opts)
	opts = opts or {}
	if opts.dir ~= nil then
		assert(type(opts.dir) == "string" and #opts.dir > 0, "dir must be a non-empty string")
		table.insert(args, "-C")
		table.insert(args, opts.dir)
	end
end

---Generic constructor: `git [global opts] <subcmd> ...`
---@param subcmd string
---@param argv string[]|nil
---@param opts GitCommonOpts|nil
---@return ward.Cmd
function Git.cmd(subcmd, argv, opts)
	validate_bin(Git.bin)
	assert(type(subcmd) == "string" and #subcmd > 0, "subcmd must be a non-empty string")

	local args = { Git.bin }
	apply_common(args, opts)
	table.insert(args, subcmd)
	if argv ~= nil then
		for _, v in ipairs(argv) do
			table.insert(args, tostring(v))
		end
	end
	return _cmd.cmd(table.unpack(args))
end

---`git status`
---@param opts GitStatusOpts|nil
---@return ward.Cmd
function Git.status(opts)
	opts = opts or {}
	local argv = {}
	if opts.short then
		table.insert(argv, "-s")
	end
	if opts.branch then
		table.insert(argv, "-b")
	end
	if opts.porcelain then
		table.insert(argv, "--porcelain=v1")
	end
	if opts.extra ~= nil then
		for _, v in ipairs(opts.extra) do
			table.insert(argv, v)
		end
	end
	return Git.cmd("status", argv, opts)
end

---`git rev-parse --show-toplevel`
---@param opts GitCommonOpts|nil
---@return ward.Cmd
function Git.root(opts)
	return Git.cmd("rev-parse", { "--show-toplevel" }, opts)
end

---`git rev-parse --is-inside-work-tree` (exit code indicates repo state)
---@param opts GitCommonOpts|nil
---@return ward.Cmd
function Git.is_repo(opts)
	return Git.cmd("rev-parse", { "--is-inside-work-tree" }, opts)
end

---`git clone <url> [dest]`
---@param url string
---@param dest string|nil
---@param opts GitCloneOpts|nil
---@return ward.Cmd
function Git.clone(url, dest, opts)
	opts = opts or {}
	assert(type(url) == "string" and #url > 0, "url must be a non-empty string")

	local argv = {}
	if opts.depth ~= nil then
		assert(
			type(opts.depth) == "number" and opts.depth > 0 and math.floor(opts.depth) == opts.depth,
			"depth must be a positive integer"
		)
		table.insert(argv, "--depth")
		table.insert(argv, tostring(opts.depth))
	end
	if opts.branch ~= nil then
		validate_not_flag(opts.branch, "branch")
		table.insert(argv, "--branch")
		table.insert(argv, opts.branch)
	end
	if opts.recursive then
		table.insert(argv, "--recursive")
	end
	if opts.extra ~= nil then
		for _, v in ipairs(opts.extra) do
			table.insert(argv, v)
		end
	end
	table.insert(argv, url)
	if dest ~= nil then
		assert(type(dest) == "string" and #dest > 0, "dest must be a non-empty string")
		table.insert(argv, dest)
	end
	-- `clone` does not support `-C` meaningfully (it would require target dir
	-- existence); accept opts but ignore `dir` by passing nil.
	return Git.cmd("clone", argv, nil)
end

---`git push [remote] [branch]`
---@param remote string|nil
---@param branch string|nil
---@param opts GitPushOpts|nil
---@return ward.Cmd
function Git.push(remote, branch, opts)
	opts = opts or {}
	local argv = {}
	if opts.upstream then
		table.insert(argv, "-u")
	end
	if opts.extra ~= nil then
		for _, v in ipairs(opts.extra) do
			table.insert(argv, v)
		end
	end
	if remote ~= nil then
		validate_not_flag(remote, "remote")
		table.insert(argv, remote)
	end
	if branch ~= nil then
		assert(type(branch) == "string" and #branch > 0, "branch must be a non-empty string")
		table.insert(argv, branch)
	end
	return Git.cmd("push", argv, opts)
end

return {
	Git = Git,
}
