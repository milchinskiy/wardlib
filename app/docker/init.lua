---@diagnostic disable: undefined-doc-name

-- docker wrapper module
--
-- Thin wrappers around `docker` that construct CLI invocations and return
-- `ward.process.cmd(...)` objects.
--
-- This module intentionally does not parse output.

local _cmd = require("ward.process")
local validate = require("util.validate")
local ensure = require("tools.ensure")
local args_util = require("util.args")

---@class DockerRunOpts
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

---@class DockerExecOpts
---@field detach boolean? `-d`
---@field interactive boolean? `-i`
---@field tty boolean? `-t`
---@field user string? `-u <user>`
---@field workdir string? `-w <dir>`
---@field env string|string[]? `-e <k=v>` (repeatable)
---@field extra string[]? Extra args appended after modeled options

---@class DockerBuildOpts
---@field tag string|string[]? `-t <tag>` (repeatable)
---@field file string? `-f <dockerfile>`
---@field build_arg string|string[]? `--build-arg <k=v>` (repeatable)
---@field target string? `--target <stage>`
---@field platform string? `--platform <platform>`
---@field pull boolean? `--pull`
---@field no_cache boolean? `--no-cache`
---@field progress string? `--progress <mode>`
---@field extra string[]? Extra args appended after modeled options

---@class DockerPsOpts
---@field all boolean? `-a`
---@field quiet boolean? `-q`
---@field no_trunc boolean? `--no-trunc`
---@field latest boolean? `-l`
---@field last integer? `-n <n>`
---@field size boolean? `-s`
---@field format string? `--format <fmt>`
---@field filter string|string[]? `--filter <filter>` (repeatable)
---@field extra string[]? Extra args appended after modeled options

---@class DockerImagesOpts
---@field all boolean? `-a`
---@field quiet boolean? `-q`
---@field no_trunc boolean? `--no-trunc`
---@field digests boolean? `--digests`
---@field format string? `--format <fmt>`
---@field filter string|string[]? `--filter <filter>` (repeatable)
---@field extra string[]? Extra args appended after modeled options

---@class DockerLogsOpts
---@field follow boolean? `-f`
---@field timestamps boolean? `-t`
---@field details boolean? `--details`
---@field since string? `--since <time>`
---@field until string? `--until <time>`
---@field tail string|integer? `--tail <n|all>`
---@field extra string[]? Extra args appended after modeled options

---@class DockerRmOpts
---@field force boolean? `-f`
---@field volumes boolean? `-v`
---@field link boolean? `-l`
---@field extra string[]? Extra args appended after modeled options

---@class DockerRmiOpts
---@field force boolean? `-f`
---@field no_prune boolean? `--no-prune`
---@field extra string[]? Extra args appended after modeled options

---@class DockerStopOpts
---@field time integer? `-t <seconds>`
---@field extra string[]? Extra args appended after modeled options

---@class DockerInspectOpts
---@field format string? `-f <format>`
---@field size boolean? `-s`
---@field type string? `--type <type>`
---@field extra string[]? Extra args appended after modeled options

---@class DockerLoginOpts
---@field username string? `-u <user>`
---@field password_stdin boolean? `--password-stdin`
---@field extra string[]? Extra args appended after modeled options

---@class Docker
---@field bin string Executable name or path to `docker`
---@field cmd fun(subcmd: string, argv: string|string[]|nil): ward.Cmd
---@field run fun(image: string, cmdline: string|string[]|nil, opts: DockerRunOpts|nil): ward.Cmd
---@field exec fun(container: string, cmdline: string|string[]|nil, opts: DockerExecOpts|nil): ward.Cmd
---@field build fun(context: string|nil, opts: DockerBuildOpts|nil): ward.Cmd
---@field pull fun(image: string, opts: { extra: string[]? }|nil): ward.Cmd
---@field push fun(image: string, opts: { extra: string[]? }|nil): ward.Cmd
---@field ps fun(opts: DockerPsOpts|nil): ward.Cmd
---@field images fun(opts: DockerImagesOpts|nil): ward.Cmd
---@field logs fun(container: string, opts: DockerLogsOpts|nil): ward.Cmd
---@field rm fun(containers: string|string[], opts: DockerRmOpts|nil): ward.Cmd
---@field rmi fun(images: string|string[], opts: DockerRmiOpts|nil): ward.Cmd
---@field stop fun(containers: string|string[], opts: DockerStopOpts|nil): ward.Cmd
---@field start fun(containers: string|string[], opts: { extra: string[]? }|nil): ward.Cmd
---@field restart fun(containers: string|string[], opts: DockerStopOpts|nil): ward.Cmd
---@field inspect fun(targets: string|string[], opts: DockerInspectOpts|nil): ward.Cmd
---@field tag fun(source: string, target: string, opts: { extra: string[]? }|nil): ward.Cmd
---@field login fun(registry: string|nil, opts: DockerLoginOpts|nil): ward.Cmd
---@field logout fun(registry: string|nil, opts: { extra: string[]? }|nil): ward.Cmd
---@field raw fun(argv: string|string[], opts: { extra: string[]? }|nil): ward.Cmd
local Docker = {
	bin = "docker",
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
---@param opts DockerRunOpts|nil
local function apply_run_opts(args, opts)
	opts = opts or {}
	args_util
		.parser(args, opts)
		:flag("detach", "-d")
		:flag("interactive", "-i")
		:flag("tty", "-t")
		:flag("rm", "--rm")
		:value_string("name", "--name", "name")
		:value_string("hostname", "--hostname", "hostname")
		:value_string("workdir", "-w", "workdir")
		:value_string("user", "-u", "user")
		:value_string("entrypoint", "--entrypoint", "entrypoint")
		:value_string("network", "--network", "network")
		:value_string("platform", "--platform", "platform")
		:value_string("pull", "--pull", "pull")
		:flag("privileged", "--privileged")
		:repeatable("env", "-e", {
			validate = function(v, l)
				validate.non_empty_string(v, l)
			end,
		})
		:repeatable("env_file", "--env-file", {
			validate = function(v, l)
				validate.non_empty_string(v, l)
			end,
		})
		:repeatable("publish", "-p", {
			validate = function(v, l)
				validate.non_empty_string(v, l)
			end,
		})
		:repeatable("volume", "-v", {
			validate = function(v, l)
				validate.non_empty_string(v, l)
			end,
		})
		:repeatable("add_host", "--add-host", {
			validate = function(v, l)
				validate.non_empty_string(v, l)
			end,
		})
		:repeatable("label", "--label", {
			validate = function(v, l)
				validate.non_empty_string(v, l)
			end,
		})
		:repeatable("cap_add", "--cap-add", {
			validate = function(v, l)
				validate.non_empty_string(v, l)
			end,
		})
		:repeatable("cap_drop", "--cap-drop", {
			validate = function(v, l)
				validate.non_empty_string(v, l)
			end,
		})
		:extra()
end

---@param args string[]
---@param opts DockerExecOpts|nil
local function apply_exec_opts(args, opts)
	opts = opts or {}
	args_util
		.parser(args, opts)
		:flag("detach", "-d")
		:flag("interactive", "-i")
		:flag("tty", "-t")
		:value_string("user", "-u", "user")
		:value_string("workdir", "-w", "workdir")
		:repeatable("env", "-e", {
			validate = function(v, l)
				validate.non_empty_string(v, l)
			end,
		})
		:extra()
end

---@param args string[]
---@param opts DockerBuildOpts|nil
local function apply_build_opts(args, opts)
	opts = opts or {}
	args_util
		.parser(args, opts)
		:repeatable("tag", "-t", {
			validate = function(v, l)
				validate.non_empty_string(v, l)
			end,
		})
		:value_string("file", "-f", "file")
		:repeatable("build_arg", "--build-arg", {
			validate = function(v, l)
				validate.non_empty_string(v, l)
			end,
		})
		:value_string("target", "--target", "target")
		:value_string("platform", "--platform", "platform")
		:flag("pull", "--pull")
		:flag("no_cache", "--no-cache")
		:value_string("progress", "--progress", "progress")
		:extra()
end

---@param args string[]
---@param opts DockerPsOpts|nil
local function apply_ps_opts(args, opts)
	opts = opts or {}
	args_util
		.parser(args, opts)
		:flag("all", "-a")
		:flag("quiet", "-q")
		:flag("no_trunc", "--no-trunc")
		:flag("latest", "-l")
		:value_number("last", "-n", { integer = true, non_negative = true })
		:flag("size", "-s")
		:value_string("format", "--format", "format")
		:repeatable("filter", "--filter", {
			validate = function(v, l)
				validate.non_empty_string(v, l)
			end,
		})
		:extra()
end

---@param args string[]
---@param opts DockerImagesOpts|nil
local function apply_images_opts(args, opts)
	opts = opts or {}
	args_util
		.parser(args, opts)
		:flag("all", "-a")
		:flag("quiet", "-q")
		:flag("no_trunc", "--no-trunc")
		:flag("digests", "--digests")
		:value_string("format", "--format", "format")
		:repeatable("filter", "--filter", {
			validate = function(v, l)
				validate.non_empty_string(v, l)
			end,
		})
		:extra()
end

---@param args string[]
---@param opts DockerLogsOpts|nil
local function apply_logs_opts(args, opts)
	opts = opts or {}
	args_util
		.parser(args, opts)
		:flag("follow", "-f")
		:flag("timestamps", "-t")
		:flag("details", "--details")
		:value_string("since", "--since", "since")
		:value_string("until", "--until", "until")
		:value("tail", "--tail", {
			validate = function(v, _)
				assert(type(v) == "string" or type(v) == "number", "tail must be a string or number")
			end,
		})
		:extra()
end

---@param args string[]
---@param opts DockerRmOpts|nil
local function apply_rm_opts(args, opts)
	opts = opts or {}
	args_util.parser(args, opts):flag("force", "-f"):flag("volumes", "-v"):flag("link", "-l"):extra()
end

---@param args string[]
---@param opts DockerRmiOpts|nil
local function apply_rmi_opts(args, opts)
	opts = opts or {}
	args_util.parser(args, opts):flag("force", "-f"):flag("no_prune", "--no-prune"):extra()
end

---@param args string[]
---@param opts DockerStopOpts|nil
local function apply_stop_opts(args, opts)
	opts = opts or {}
	args_util.parser(args, opts):value_number("time", "-t", { integer = true, non_negative = true }):extra()
end

---@param args string[]
---@param opts DockerInspectOpts|nil
local function apply_inspect_opts(args, opts)
	opts = opts or {}
	args_util
		.parser(args, opts)
		:value_string("format", "-f", "format")
		:flag("size", "-s")
		:value_string("type", "--type", "type")
		:extra()
end

---@param args string[]
---@param opts DockerLoginOpts|nil
local function apply_login_opts(args, opts)
	opts = opts or {}
	args_util
		.parser(args, opts)
		:value_string("username", "-u", "username")
		:flag("password_stdin", "--password-stdin")
		:extra()
end

---Generic helper: `docker <subcmd> [argv...]`
---@param subcmd string
---@param argv string|string[]|nil
---@return ward.Cmd
function Docker.cmd(subcmd, argv)
	ensure.bin(Docker.bin, { label = "docker binary" })
	validate.non_empty_string(subcmd, "subcmd")
	local args = { Docker.bin, subcmd }
	if argv ~= nil then
		local av = args_util.normalize_string_or_array(argv, "argv")
		for _, s in ipairs(av) do
			args[#args + 1] = s
		end
	end
	return _cmd.cmd(table.unpack(args))
end

---`docker run [opts...] <image> [cmd...]`
---@param image string
---@param cmdline string|string[]|nil
---@param opts DockerRunOpts|nil
---@return ward.Cmd
function Docker.run(image, cmdline, opts)
	ensure.bin(Docker.bin, { label = "docker binary" })
	validate.non_empty_string(image, "image")
	local args = { Docker.bin, "run" }
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

---`docker exec [opts...] <container> [cmd...]`
---@param container string
---@param cmdline string|string[]|nil
---@param opts DockerExecOpts|nil
---@return ward.Cmd
function Docker.exec(container, cmdline, opts)
	ensure.bin(Docker.bin, { label = "docker binary" })
	validate.non_empty_string(container, "container")
	local args = { Docker.bin, "exec" }
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

---`docker build [opts...] <context>`
---@param context string|nil If nil, defaults to '.'
---@param opts DockerBuildOpts|nil
---@return ward.Cmd
function Docker.build(context, opts)
	ensure.bin(Docker.bin, { label = "docker binary" })
	local ctx = context or "."
	validate.non_empty_string(ctx, "context")
	local args = { Docker.bin, "build" }
	apply_build_opts(args, opts)
	args[#args + 1] = ctx
	return _cmd.cmd(table.unpack(args))
end

---`docker pull <image>`
---@param image string
---@param opts { extra: string[]? }|nil
---@return ward.Cmd
function Docker.pull(image, opts)
	ensure.bin(Docker.bin, { label = "docker binary" })
	validate.non_empty_string(image, "image")
	local args = { Docker.bin, "pull", image }
	args_util.append_extra(args, (opts or {}).extra)
	return _cmd.cmd(table.unpack(args))
end

---`docker push <image>`
---@param image string
---@param opts { extra: string[]? }|nil
---@return ward.Cmd
function Docker.push(image, opts)
	ensure.bin(Docker.bin, { label = "docker binary" })
	validate.non_empty_string(image, "image")
	local args = { Docker.bin, "push", image }
	args_util.append_extra(args, (opts or {}).extra)
	return _cmd.cmd(table.unpack(args))
end

---`docker ps [opts...]`
---@param opts DockerPsOpts|nil
---@return ward.Cmd
function Docker.ps(opts)
	ensure.bin(Docker.bin, { label = "docker binary" })
	local args = { Docker.bin, "ps" }
	apply_ps_opts(args, opts)
	return _cmd.cmd(table.unpack(args))
end

---`docker images [opts...]`
---@param opts DockerImagesOpts|nil
---@return ward.Cmd
function Docker.images(opts)
	ensure.bin(Docker.bin, { label = "docker binary" })
	local args = { Docker.bin, "images" }
	apply_images_opts(args, opts)
	return _cmd.cmd(table.unpack(args))
end

---`docker logs [opts...] <container>`
---@param container string
---@param opts DockerLogsOpts|nil
---@return ward.Cmd
function Docker.logs(container, opts)
	ensure.bin(Docker.bin, { label = "docker binary" })
	validate.non_empty_string(container, "container")
	local args = { Docker.bin, "logs" }
	apply_logs_opts(args, opts)
	args[#args + 1] = container
	return _cmd.cmd(table.unpack(args))
end

---`docker rm [opts...] <containers...>`
---@param containers string|string[]
---@param opts DockerRmOpts|nil
---@return ward.Cmd
function Docker.rm(containers, opts)
	ensure.bin(Docker.bin, { label = "docker binary" })
	local args = { Docker.bin, "rm" }
	apply_rm_opts(args, opts)
	for _, c in ipairs(normalize_list(containers, "containers")) do
		args[#args + 1] = c
	end
	return _cmd.cmd(table.unpack(args))
end

---`docker rmi [opts...] <images...>`
---@param images string|string[]
---@param opts DockerRmiOpts|nil
---@return ward.Cmd
function Docker.rmi(images, opts)
	ensure.bin(Docker.bin, { label = "docker binary" })
	local args = { Docker.bin, "rmi" }
	apply_rmi_opts(args, opts)
	for _, img in ipairs(normalize_list(images, "images")) do
		args[#args + 1] = img
	end
	return _cmd.cmd(table.unpack(args))
end

---`docker stop [opts...] <containers...>`
---@param containers string|string[]
---@param opts DockerStopOpts|nil
---@return ward.Cmd
function Docker.stop(containers, opts)
	ensure.bin(Docker.bin, { label = "docker binary" })
	local args = { Docker.bin, "stop" }
	apply_stop_opts(args, opts)
	for _, c in ipairs(normalize_list(containers, "containers")) do
		args[#args + 1] = c
	end
	return _cmd.cmd(table.unpack(args))
end

---`docker start <containers...>`
---@param containers string|string[]
---@param opts { extra: string[]? }|nil
---@return ward.Cmd
function Docker.start(containers, opts)
	ensure.bin(Docker.bin, { label = "docker binary" })
	local args = { Docker.bin, "start" }
	args_util.append_extra(args, (opts or {}).extra)
	for _, c in ipairs(normalize_list(containers, "containers")) do
		args[#args + 1] = c
	end
	return _cmd.cmd(table.unpack(args))
end

---`docker restart [opts...] <containers...>`
---@param containers string|string[]
---@param opts DockerStopOpts|nil
---@return ward.Cmd
function Docker.restart(containers, opts)
	ensure.bin(Docker.bin, { label = "docker binary" })
	local args = { Docker.bin, "restart" }
	apply_stop_opts(args, opts)
	for _, c in ipairs(normalize_list(containers, "containers")) do
		args[#args + 1] = c
	end
	return _cmd.cmd(table.unpack(args))
end

---`docker inspect [opts...] <targets...>`
---@param targets string|string[]
---@param opts DockerInspectOpts|nil
---@return ward.Cmd
function Docker.inspect(targets, opts)
	ensure.bin(Docker.bin, { label = "docker binary" })
	local args = { Docker.bin, "inspect" }
	apply_inspect_opts(args, opts)
	for _, t in ipairs(normalize_list(targets, "targets")) do
		args[#args + 1] = t
	end
	return _cmd.cmd(table.unpack(args))
end

---`docker tag <source> <target>`
---@param source string
---@param target string
---@param opts { extra: string[]? }|nil
---@return ward.Cmd
function Docker.tag(source, target, opts)
	ensure.bin(Docker.bin, { label = "docker binary" })
	validate.non_empty_string(source, "source")
	validate.non_empty_string(target, "target")
	local args = { Docker.bin, "tag", source, target }
	args_util.append_extra(args, (opts or {}).extra)
	return _cmd.cmd(table.unpack(args))
end

---`docker login [registry]`
---
---Note: for security, the wrapper does not accept a password string; prefer `--password-stdin`.
---@param registry string|nil
---@param opts DockerLoginOpts|nil
---@return ward.Cmd
function Docker.login(registry, opts)
	ensure.bin(Docker.bin, { label = "docker binary" })
	local args = { Docker.bin, "login" }
	apply_login_opts(args, opts)
	if registry ~= nil then
		validate.non_empty_string(registry, "registry")
		args[#args + 1] = registry
	end
	return _cmd.cmd(table.unpack(args))
end

---`docker logout [registry]`
---@param registry string|nil
---@param opts { extra: string[]? }|nil
---@return ward.Cmd
function Docker.logout(registry, opts)
	ensure.bin(Docker.bin, { label = "docker binary" })
	local args = { Docker.bin, "logout" }
	args_util.append_extra(args, (opts or {}).extra)
	if registry ~= nil then
		validate.non_empty_string(registry, "registry")
		args[#args + 1] = registry
	end
	return _cmd.cmd(table.unpack(args))
end

---Low-level escape hatch.
---Builds: `docker <argv...>` (with optional `extra` inserted first)
---@param argv string|string[]
---@param opts { extra: string[]? }|nil
---@return ward.Cmd
function Docker.raw(argv, opts)
	ensure.bin(Docker.bin, { label = "docker binary" })
	local args = { Docker.bin }
	args_util.append_extra(args, (opts or {}).extra)
	local av = args_util.normalize_string_or_array(argv, "argv")
	for _, s in ipairs(av) do
		args[#args + 1] = s
	end
	return _cmd.cmd(table.unpack(args))
end

return {
	Docker = Docker,
}
