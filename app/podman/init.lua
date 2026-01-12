---@diagnostic disable: undefined-doc-name

-- podman wrapper module
--
-- Thin wrappers around `podman` that construct CLI invocations and return
-- `ward.process.cmd(...)` objects.
--
-- This module intentionally does not parse output.

local _cmd = require("ward.process")
local validate = require("util.validate")
local ensure = require("tools.ensure")
local args_util = require("util.args")

---@class PodmanRunOpts
---@field detach boolean? `-d`
---@field interactive boolean? `-i`
---@field tty boolean? `-t`
---@field rm boolean? `--rm`
---@field name string? `--name <name>`
---@field hostname string? `--hostname <hostname>`
---@field workdir string? `-w <dir>`
---@field user string? `-u <user>`
---@field entrypoint string? `--entrypoint <entrypoint>`
---@field env string|string[]? `-e <k=v>` (repeatable)
---@field env_file string|string[]? `--env-file <file>` (repeatable)
---@field publish string|string[]? `-p <host:container>` (repeatable)
---@field volume string|string[]? `-v <host:container>` (repeatable)
---@field network string? `--network <net>`
---@field add_host string|string[]? `--add-host <host:ip>` (repeatable)
---@field label string|string[]? `--label <k=v>` (repeatable)
---@field privileged boolean? `--privileged`
---@field cap_add string|string[]? `--cap-add <cap>` (repeatable)
---@field cap_drop string|string[]? `--cap-drop <cap>` (repeatable)
---@field platform string? `--platform <platform>`
---@field pull string? `--pull <policy>`
---@field extra string[]? Extra args appended after modeled options

---@class PodmanExecOpts
---@field detach boolean? `-d`
---@field interactive boolean? `-i`
---@field tty boolean? `-t`
---@field user string? `-u <user>`
---@field workdir string? `-w <dir>`
---@field env string|string[]? `-e <k=v>` (repeatable)
---@field extra string[]? Extra args appended after modeled options

---@class PodmanBuildOpts
---@field tag string|string[]? `-t <tag>` (repeatable)
---@field file string? `-f <containerfile>`
---@field build_arg string|string[]? `--build-arg <k=v>` (repeatable)
---@field target string? `--target <stage>`
---@field platform string? `--platform <platform>`
---@field pull boolean? `--pull`
---@field no_cache boolean? `--no-cache`
---@field layers boolean? `--layers`
---@field format string? `--format <format>`
---@field extra string[]? Extra args appended after modeled options

---@class PodmanPsOpts
---@field all boolean? `-a`
---@field quiet boolean? `-q`
---@field no_trunc boolean? `--no-trunc`
---@field latest boolean? `-l`
---@field last integer? `-n <n>`
---@field size boolean? `-s`
---@field format string? `--format <fmt>`
---@field filter string|string[]? `--filter <filter>` (repeatable)
---@field extra string[]? Extra args appended after modeled options

---@class PodmanImagesOpts
---@field all boolean? `-a`
---@field quiet boolean? `-q`
---@field no_trunc boolean? `--no-trunc`
---@field digests boolean? `--digests`
---@field format string? `--format <fmt>`
---@field filter string|string[]? `--filter <filter>` (repeatable)
---@field extra string[]? Extra args appended after modeled options

---@class PodmanLogsOpts
---@field follow boolean? `-f`
---@field timestamps boolean? `-t`
---@field since string? `--since <time>`
---@field until string? `--until <time>`
---@field tail string|integer? `--tail <n|all>`
---@field extra string[]? Extra args appended after modeled options

---@class PodmanRmOpts
---@field force boolean? `-f`
---@field volumes boolean? `-v`
---@field extra string[]? Extra args appended after modeled options

---@class PodmanRmiOpts
---@field force boolean? `-f`
---@field extra string[]? Extra args appended after modeled options

---@class PodmanStopOpts
---@field time integer? `-t <seconds>`
---@field extra string[]? Extra args appended after modeled options

---@class PodmanInspectOpts
---@field format string? `-f <format>`
---@field size boolean? `-s`
---@field type string? `--type <type>`
---@field extra string[]? Extra args appended after modeled options

---@class PodmanLoginOpts
---@field username string? `-u <user>`
---@field password_stdin boolean? `--password-stdin`
---@field extra string[]? Extra args appended after modeled options

---@class Podman
---@field bin string Executable name or path to `podman`
---@field cmd fun(subcmd: string, argv: string|string[]|nil): ward.Cmd
---@field run fun(image: string, cmdline: string|string[]|nil, opts: PodmanRunOpts|nil): ward.Cmd
---@field exec fun(container: string, cmdline: string|string[]|nil, opts: PodmanExecOpts|nil): ward.Cmd
---@field build fun(context: string|nil, opts: PodmanBuildOpts|nil): ward.Cmd
---@field pull fun(image: string, opts: { extra: string[]? }|nil): ward.Cmd
---@field push fun(image: string, opts: { extra: string[]? }|nil): ward.Cmd
---@field ps fun(opts: PodmanPsOpts|nil): ward.Cmd
---@field images fun(opts: PodmanImagesOpts|nil): ward.Cmd
---@field logs fun(container: string, opts: PodmanLogsOpts|nil): ward.Cmd
---@field rm fun(containers: string|string[], opts: PodmanRmOpts|nil): ward.Cmd
---@field rmi fun(images: string|string[], opts: PodmanRmiOpts|nil): ward.Cmd
---@field stop fun(containers: string|string[], opts: PodmanStopOpts|nil): ward.Cmd
---@field start fun(containers: string|string[], opts: { extra: string[]? }|nil): ward.Cmd
---@field restart fun(containers: string|string[], opts: PodmanStopOpts|nil): ward.Cmd
---@field inspect fun(targets: string|string[], opts: PodmanInspectOpts|nil): ward.Cmd
---@field tag fun(source: string, target: string, opts: { extra: string[]? }|nil): ward.Cmd
---@field login fun(registry: string|nil, opts: PodmanLoginOpts|nil): ward.Cmd
---@field logout fun(registry: string|nil, opts: { extra: string[]? }|nil): ward.Cmd
---@field raw fun(argv: string|string[], opts: { extra: string[]? }|nil): ward.Cmd
local Podman = {
	bin = "podman",
}

---@param v string|string[]
---@param label string
---@return string[]
local function normalize_list(v, label)
	local list = args_util.normalize_string_or_array(v, label)
	assert(#list > 0, label .. " must not be empty")
	for _, s in ipairs(list) do
		validate.not_flag(s, label)
	end
	return list
end

---@param args string[]
---@param opts PodmanRunOpts|nil
local function apply_run_opts(args, opts)
	opts = opts or {}
	if opts.detach then
		args[#args + 1] = "-d"
	end
	if opts.interactive then
		args[#args + 1] = "-i"
	end
	if opts.tty then
		args[#args + 1] = "-t"
	end
	if opts.rm then
		args[#args + 1] = "--rm"
	end
	if opts.name ~= nil then
		validate.non_empty_string(opts.name, "name")
		args[#args + 1] = "--name"
		args[#args + 1] = opts.name
	end
	if opts.hostname ~= nil then
		validate.non_empty_string(opts.hostname, "hostname")
		args[#args + 1] = "--hostname"
		args[#args + 1] = opts.hostname
	end
	if opts.workdir ~= nil then
		validate.non_empty_string(opts.workdir, "workdir")
		args[#args + 1] = "-w"
		args[#args + 1] = opts.workdir
	end
	if opts.user ~= nil then
		validate.non_empty_string(opts.user, "user")
		args[#args + 1] = "-u"
		args[#args + 1] = opts.user
	end
	if opts.entrypoint ~= nil then
		validate.non_empty_string(opts.entrypoint, "entrypoint")
		args[#args + 1] = "--entrypoint"
		args[#args + 1] = opts.entrypoint
	end
	if opts.network ~= nil then
		validate.non_empty_string(opts.network, "network")
		args[#args + 1] = "--network"
		args[#args + 1] = opts.network
	end
	if opts.platform ~= nil then
		validate.non_empty_string(opts.platform, "platform")
		args[#args + 1] = "--platform"
		args[#args + 1] = opts.platform
	end
	if opts.pull ~= nil then
		validate.non_empty_string(opts.pull, "pull")
		args[#args + 1] = "--pull"
		args[#args + 1] = opts.pull
	end
	if opts.privileged then
		args[#args + 1] = "--privileged"
	end

	if opts.env ~= nil then
		args_util.add_repeatable(args, opts.env, "-e", "env")
	end
	if opts.env_file ~= nil then
		args_util.add_repeatable(args, opts.env_file, "--env-file", "env_file")
	end
	if opts.publish ~= nil then
		args_util.add_repeatable(args, opts.publish, "-p", "publish")
	end
	if opts.volume ~= nil then
		args_util.add_repeatable(args, opts.volume, "-v", "volume")
	end
	if opts.add_host ~= nil then
		args_util.add_repeatable(args, opts.add_host, "--add-host", "add_host")
	end
	if opts.label ~= nil then
		args_util.add_repeatable(args, opts.label, "--label", "label")
	end
	if opts.cap_add ~= nil then
		args_util.add_repeatable(args, opts.cap_add, "--cap-add", "cap_add")
	end
	if opts.cap_drop ~= nil then
		args_util.add_repeatable(args, opts.cap_drop, "--cap-drop", "cap_drop")
	end

	args_util.append_extra(args, opts.extra)
end

---@param args string[]
---@param opts PodmanExecOpts|nil
local function apply_exec_opts(args, opts)
	opts = opts or {}
	if opts.detach then
		args[#args + 1] = "-d"
	end
	if opts.interactive then
		args[#args + 1] = "-i"
	end
	if opts.tty then
		args[#args + 1] = "-t"
	end
	if opts.user ~= nil then
		validate.non_empty_string(opts.user, "user")
		args[#args + 1] = "-u"
		args[#args + 1] = opts.user
	end
	if opts.workdir ~= nil then
		validate.non_empty_string(opts.workdir, "workdir")
		args[#args + 1] = "-w"
		args[#args + 1] = opts.workdir
	end
	if opts.env ~= nil then
		args_util.add_repeatable(args, opts.env, "-e", "env")
	end
	args_util.append_extra(args, opts.extra)
end

---@param args string[]
---@param opts PodmanBuildOpts|nil
local function apply_build_opts(args, opts)
	opts = opts or {}
	if opts.tag ~= nil then
		args_util.add_repeatable(args, opts.tag, "-t", "tag")
	end
	if opts.file ~= nil then
		validate.non_empty_string(opts.file, "file")
		args[#args + 1] = "-f"
		args[#args + 1] = opts.file
	end
	if opts.build_arg ~= nil then
		args_util.add_repeatable(args, opts.build_arg, "--build-arg", "build_arg")
	end
	if opts.target ~= nil then
		validate.non_empty_string(opts.target, "target")
		args[#args + 1] = "--target"
		args[#args + 1] = opts.target
	end
	if opts.platform ~= nil then
		validate.non_empty_string(opts.platform, "platform")
		args[#args + 1] = "--platform"
		args[#args + 1] = opts.platform
	end
	if opts.pull then
		args[#args + 1] = "--pull"
	end
	if opts.no_cache then
		args[#args + 1] = "--no-cache"
	end
	if opts.layers then
		args[#args + 1] = "--layers"
	end
	if opts.format ~= nil then
		validate.non_empty_string(opts.format, "format")
		args[#args + 1] = "--format"
		args[#args + 1] = opts.format
	end
	args_util.append_extra(args, opts.extra)
end

---@param args string[]
---@param opts PodmanPsOpts|nil
local function apply_ps_opts(args, opts)
	opts = opts or {}
	if opts.all then
		args[#args + 1] = "-a"
	end
	if opts.quiet then
		args[#args + 1] = "-q"
	end
	if opts.no_trunc then
		args[#args + 1] = "--no-trunc"
	end
	if opts.latest then
		args[#args + 1] = "-l"
	end
	if opts.last ~= nil then
		validate.integer_min(opts.last, "last", 0)
		args[#args + 1] = "-n"
		args[#args + 1] = tostring(opts.last)
	end
	if opts.size then
		args[#args + 1] = "-s"
	end
	if opts.format ~= nil then
		validate.non_empty_string(opts.format, "format")
		args[#args + 1] = "--format"
		args[#args + 1] = opts.format
	end
	if opts.filter ~= nil then
		args_util.add_repeatable(args, opts.filter, "--filter", "filter")
	end
	args_util.append_extra(args, opts.extra)
end

---@param args string[]
---@param opts PodmanImagesOpts|nil
local function apply_images_opts(args, opts)
	opts = opts or {}
	if opts.all then
		args[#args + 1] = "-a"
	end
	if opts.quiet then
		args[#args + 1] = "-q"
	end
	if opts.no_trunc then
		args[#args + 1] = "--no-trunc"
	end
	if opts.digests then
		args[#args + 1] = "--digests"
	end
	if opts.format ~= nil then
		validate.non_empty_string(opts.format, "format")
		args[#args + 1] = "--format"
		args[#args + 1] = opts.format
	end
	if opts.filter ~= nil then
		args_util.add_repeatable(args, opts.filter, "--filter", "filter")
	end
	args_util.append_extra(args, opts.extra)
end

---@param args string[]
---@param opts PodmanLogsOpts|nil
local function apply_logs_opts(args, opts)
	opts = opts or {}
	if opts.follow then
		args[#args + 1] = "-f"
	end
	if opts.timestamps then
		args[#args + 1] = "-t"
	end
	if opts.since ~= nil then
		validate.non_empty_string(opts.since, "since")
		args[#args + 1] = "--since"
		args[#args + 1] = opts.since
	end
	if opts["until"] ~= nil then
		validate.non_empty_string(opts["until"], "until")
		args[#args + 1] = "--until"
		args[#args + 1] = opts["until"]
	end
	if opts.tail ~= nil then
		args[#args + 1] = "--tail"
		args[#args + 1] = tostring(opts.tail)
	end
	args_util.append_extra(args, opts.extra)
end

---@param args string[]
---@param opts PodmanRmOpts|nil
local function apply_rm_opts(args, opts)
	opts = opts or {}
	if opts.force then
		args[#args + 1] = "-f"
	end
	if opts.volumes then
		args[#args + 1] = "-v"
	end
	args_util.append_extra(args, opts.extra)
end

---@param args string[]
---@param opts PodmanRmiOpts|nil
local function apply_rmi_opts(args, opts)
	opts = opts or {}
	if opts.force then
		args[#args + 1] = "-f"
	end
	args_util.append_extra(args, opts.extra)
end

---@param args string[]
---@param opts PodmanStopOpts|nil
local function apply_stop_opts(args, opts)
	opts = opts or {}
	if opts.time ~= nil then
		validate.integer_min(opts.time, "time", 0)
		args[#args + 1] = "-t"
		args[#args + 1] = tostring(opts.time)
	end
	args_util.append_extra(args, opts.extra)
end

---@param args string[]
---@param opts PodmanInspectOpts|nil
local function apply_inspect_opts(args, opts)
	opts = opts or {}
	if opts.format ~= nil then
		validate.non_empty_string(opts.format, "format")
		args[#args + 1] = "-f"
		args[#args + 1] = opts.format
	end
	if opts.size then
		args[#args + 1] = "-s"
	end
	if opts.type ~= nil then
		validate.non_empty_string(opts.type, "type")
		args[#args + 1] = "--type"
		args[#args + 1] = opts.type
	end
	args_util.append_extra(args, opts.extra)
end

---@param args string[]
---@param opts PodmanLoginOpts|nil
local function apply_login_opts(args, opts)
	opts = opts or {}
	if opts.username ~= nil then
		validate.non_empty_string(opts.username, "username")
		args[#args + 1] = "-u"
		args[#args + 1] = opts.username
	end
	if opts.password_stdin then
		args[#args + 1] = "--password-stdin"
	end
	args_util.append_extra(args, opts.extra)
end

---Generic helper: `podman <subcmd> [argv...]`
---@param subcmd string
---@param argv string|string[]|nil
---@return ward.Cmd
function Podman.cmd(subcmd, argv)
	ensure.bin(Podman.bin, { label = "podman binary" })
	validate.non_empty_string(subcmd, "subcmd")
	local args = { Podman.bin, subcmd }
	if argv ~= nil then
		local av = args_util.normalize_string_or_array(argv, "argv")
		for _, s in ipairs(av) do
			args[#args + 1] = s
		end
	end
	return _cmd.cmd(table.unpack(args))
end

---`podman run [opts...] <image> [cmd...]`
---@param image string
---@param cmdline string|string[]|nil
---@param opts PodmanRunOpts|nil
---@return ward.Cmd
function Podman.run(image, cmdline, opts)
	ensure.bin(Podman.bin, { label = "podman binary" })
	validate.non_empty_string(image, "image")
	local args = { Podman.bin, "run" }
	apply_run_opts(args, opts)
	args[#args + 1] = image
	if cmdline ~= nil then
		local cl = args_util.normalize_string_or_array(cmdline, "cmd")
		for _, s in ipairs(cl) do
			args[#args + 1] = s
		end
	end
	return _cmd.cmd(table.unpack(args))
end

---`podman exec [opts...] <container> [cmd...]`
---@param container string
---@param cmdline string|string[]|nil
---@param opts PodmanExecOpts|nil
---@return ward.Cmd
function Podman.exec(container, cmdline, opts)
	ensure.bin(Podman.bin, { label = "podman binary" })
	validate.non_empty_string(container, "container")
	local args = { Podman.bin, "exec" }
	apply_exec_opts(args, opts)
	args[#args + 1] = container
	if cmdline ~= nil then
		local cl = args_util.normalize_string_or_array(cmdline, "cmd")
		for _, s in ipairs(cl) do
			args[#args + 1] = s
		end
	end
	return _cmd.cmd(table.unpack(args))
end

---`podman build [opts...] <context>`
---@param context string|nil If nil, defaults to '.'
---@param opts PodmanBuildOpts|nil
---@return ward.Cmd
function Podman.build(context, opts)
	ensure.bin(Podman.bin, { label = "podman binary" })
	local ctx = context or "."
	validate.non_empty_string(ctx, "context")
	local args = { Podman.bin, "build" }
	apply_build_opts(args, opts)
	args[#args + 1] = ctx
	return _cmd.cmd(table.unpack(args))
end

---`podman pull <image>`
---@param image string
---@param opts { extra: string[]? }|nil
---@return ward.Cmd
function Podman.pull(image, opts)
	ensure.bin(Podman.bin, { label = "podman binary" })
	validate.non_empty_string(image, "image")
	local args = { Podman.bin, "pull", image }
	args_util.append_extra(args, (opts or {}).extra)
	return _cmd.cmd(table.unpack(args))
end

---`podman push <image>`
---@param image string
---@param opts { extra: string[]? }|nil
---@return ward.Cmd
function Podman.push(image, opts)
	ensure.bin(Podman.bin, { label = "podman binary" })
	validate.non_empty_string(image, "image")
	local args = { Podman.bin, "push", image }
	args_util.append_extra(args, (opts or {}).extra)
	return _cmd.cmd(table.unpack(args))
end

---`podman ps [opts...]`
---@param opts PodmanPsOpts|nil
---@return ward.Cmd
function Podman.ps(opts)
	ensure.bin(Podman.bin, { label = "podman binary" })
	local args = { Podman.bin, "ps" }
	apply_ps_opts(args, opts)
	return _cmd.cmd(table.unpack(args))
end

---`podman images [opts...]`
---@param opts PodmanImagesOpts|nil
---@return ward.Cmd
function Podman.images(opts)
	ensure.bin(Podman.bin, { label = "podman binary" })
	local args = { Podman.bin, "images" }
	apply_images_opts(args, opts)
	return _cmd.cmd(table.unpack(args))
end

---`podman logs [opts...] <container>`
---@param container string
---@param opts PodmanLogsOpts|nil
---@return ward.Cmd
function Podman.logs(container, opts)
	ensure.bin(Podman.bin, { label = "podman binary" })
	validate.non_empty_string(container, "container")
	local args = { Podman.bin, "logs" }
	apply_logs_opts(args, opts)
	args[#args + 1] = container
	return _cmd.cmd(table.unpack(args))
end

---`podman rm [opts...] <containers...>`
---@param containers string|string[]
---@param opts PodmanRmOpts|nil
---@return ward.Cmd
function Podman.rm(containers, opts)
	ensure.bin(Podman.bin, { label = "podman binary" })
	local args = { Podman.bin, "rm" }
	apply_rm_opts(args, opts)
	for _, c in ipairs(normalize_list(containers, "containers")) do
		args[#args + 1] = c
	end
	return _cmd.cmd(table.unpack(args))
end

---`podman rmi [opts...] <images...>`
---@param images string|string[]
---@param opts PodmanRmiOpts|nil
---@return ward.Cmd
function Podman.rmi(images, opts)
	ensure.bin(Podman.bin, { label = "podman binary" })
	local args = { Podman.bin, "rmi" }
	apply_rmi_opts(args, opts)
	for _, img in ipairs(normalize_list(images, "images")) do
		args[#args + 1] = img
	end
	return _cmd.cmd(table.unpack(args))
end

---`podman stop [opts...] <containers...>`
---@param containers string|string[]
---@param opts PodmanStopOpts|nil
---@return ward.Cmd
function Podman.stop(containers, opts)
	ensure.bin(Podman.bin, { label = "podman binary" })
	local args = { Podman.bin, "stop" }
	apply_stop_opts(args, opts)
	for _, c in ipairs(normalize_list(containers, "containers")) do
		args[#args + 1] = c
	end
	return _cmd.cmd(table.unpack(args))
end

---`podman start <containers...>`
---@param containers string|string[]
---@param opts { extra: string[]? }|nil
---@return ward.Cmd
function Podman.start(containers, opts)
	ensure.bin(Podman.bin, { label = "podman binary" })
	local args = { Podman.bin, "start" }
	args_util.append_extra(args, (opts or {}).extra)
	for _, c in ipairs(normalize_list(containers, "containers")) do
		args[#args + 1] = c
	end
	return _cmd.cmd(table.unpack(args))
end

---`podman restart [opts...] <containers...>`
---@param containers string|string[]
---@param opts PodmanStopOpts|nil
---@return ward.Cmd
function Podman.restart(containers, opts)
	ensure.bin(Podman.bin, { label = "podman binary" })
	local args = { Podman.bin, "restart" }
	apply_stop_opts(args, opts)
	for _, c in ipairs(normalize_list(containers, "containers")) do
		args[#args + 1] = c
	end
	return _cmd.cmd(table.unpack(args))
end

---`podman inspect [opts...] <targets...>`
---@param targets string|string[]
---@param opts PodmanInspectOpts|nil
---@return ward.Cmd
function Podman.inspect(targets, opts)
	ensure.bin(Podman.bin, { label = "podman binary" })
	local args = { Podman.bin, "inspect" }
	apply_inspect_opts(args, opts)
	for _, t in ipairs(normalize_list(targets, "targets")) do
		args[#args + 1] = t
	end
	return _cmd.cmd(table.unpack(args))
end

---`podman tag <source> <target>`
---@param source string
---@param target string
---@param opts { extra: string[]? }|nil
---@return ward.Cmd
function Podman.tag(source, target, opts)
	ensure.bin(Podman.bin, { label = "podman binary" })
	validate.non_empty_string(source, "source")
	validate.non_empty_string(target, "target")
	local args = { Podman.bin, "tag", source, target }
	args_util.append_extra(args, (opts or {}).extra)
	return _cmd.cmd(table.unpack(args))
end

---`podman login [registry]`
---
---Note: for security, the wrapper does not accept a password string; prefer `--password-stdin`.
---@param registry string|nil
---@param opts PodmanLoginOpts|nil
---@return ward.Cmd
function Podman.login(registry, opts)
	ensure.bin(Podman.bin, { label = "podman binary" })
	local args = { Podman.bin, "login" }
	apply_login_opts(args, opts)
	if registry ~= nil then
		validate.non_empty_string(registry, "registry")
		args[#args + 1] = registry
	end
	return _cmd.cmd(table.unpack(args))
end

---`podman logout [registry]`
---@param registry string|nil
---@param opts { extra: string[]? }|nil
---@return ward.Cmd
function Podman.logout(registry, opts)
	ensure.bin(Podman.bin, { label = "podman binary" })
	local args = { Podman.bin, "logout" }
	args_util.append_extra(args, (opts or {}).extra)
	if registry ~= nil then
		validate.non_empty_string(registry, "registry")
		args[#args + 1] = registry
	end
	return _cmd.cmd(table.unpack(args))
end

---Low-level escape hatch.
---Builds: `podman <argv...>` (with optional `extra` inserted first)
---@param argv string|string[]
---@param opts { extra: string[]? }|nil
---@return ward.Cmd
function Podman.raw(argv, opts)
	ensure.bin(Podman.bin, { label = "podman binary" })
	local args = { Podman.bin }
	args_util.append_extra(args, (opts or {}).extra)
	local av = args_util.normalize_string_or_array(argv, "argv")
	for _, s in ipairs(av) do
		args[#args + 1] = s
	end
	return _cmd.cmd(table.unpack(args))
end

return {
	Podman = Podman,
}
