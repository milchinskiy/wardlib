---@diagnostic disable: undefined-doc-name

-- compose wrapper module
--
-- A unified wrapper for Compose commands that can target either:
--   * Docker Compose v2 plugin: `docker compose ...` (default)
--   * Podman Compose plugin:    `podman compose ...`
--
-- This module intentionally does not parse output.

local _cmd = require("ward.process")
local validate = require("util.validate")
local ensure = require("tools.ensure")
local args_util = require("util.args")

---@class ComposeOpts
---@field engine string? Engine selector. If nil or 'docker' => uses `docker`. If 'podman' => uses `podman`.
---@field project_name string? `-p <name>`
---@field file string|string[]? `-f <compose.yml>` (repeatable)
---@field env_file string|string[]? `--env-file <file>` (repeatable)
---@field profile string|string[]? `--profile <name>` (repeatable)
---@field ansi string? `--ansi <auto|never|always>`
---@field progress string? `--progress <auto|tty|plain|quiet>`
---@field extra string[]? Extra args appended after modeled options

---@class ComposeUpOpts: ComposeOpts
---@field detach boolean? `-d`
---@field build boolean? `--build`
---@field force_recreate boolean? `--force-recreate`
---@field no_recreate boolean? `--no-recreate`
---@field remove_orphans boolean? `--remove-orphans`
---@field no_start boolean? `--no-start`
---@field wait boolean? `--wait`

---@class ComposeDownOpts: ComposeOpts
---@field remove_orphans boolean? `--remove-orphans`
---@field volumes boolean? `-v`
---@field rmi string? `--rmi <all|local>`
---@field timeout integer? `-t <seconds>`

---@class ComposePsOpts: ComposeOpts
---@field all boolean? `-a`
---@field quiet boolean? `-q`
---@field status string? `--status <running|paused|exited|created|restarting|removing|dead>`
---@field format string? `--format <fmt>`

---@class ComposeLogsOpts: ComposeOpts
---@field follow boolean? `-f`
---@field timestamps boolean? `-t`
---@field tail string|integer? `--tail <n|all>`
---@field no_color boolean? `--no-color`
---@field since string? `--since <time>`
---@field until string? `--until <time>`

---@class ComposeBuildOpts: ComposeOpts
---@field pull boolean? `--pull`
---@field no_cache boolean? `--no-cache`
---@field parallel boolean? `--parallel`
---@field push boolean? `--push`

---@class ComposePullOpts: ComposeOpts
---@field include_deps boolean? `--include-deps`
---@field ignore_failures boolean? `--ignore-pull-failures`

---@class ComposeStartStopOpts: ComposeOpts
---@field timeout integer? `-t <seconds>`

---@class ComposeExecOpts: ComposeOpts
---@field detach boolean? `-d`
---@field interactive boolean? `-i`
---@field tty boolean? `-t`
---@field user string? `-u <user>`
---@field workdir string? `-w <dir>`
---@field env string|string[]? `-e <k=v>` (repeatable)

---@class ComposeRunOpts: ComposeOpts
---@field detach boolean? `-d`
---@field rm boolean? `--rm`
---@field name string? `--name <name>`
---@field entrypoint string? `--entrypoint <entrypoint>`
---@field user string? `-u <user>`
---@field workdir string? `-w <dir>`
---@field env string|string[]? `-e <k=v>` (repeatable)
---@field publish string|string[]? `-p <host:container>` (repeatable)
---@field volume string|string[]? `-v <host:container>` (repeatable)
---@field no_deps boolean? `--no-deps`
---@field service_ports boolean? `--service-ports`

---@class Compose
---@field cmd fun(subcmd: string, argv: string|string[]|nil, opts: ComposeOpts|nil): ward.Cmd
---@field up fun(services: string|string[]|nil, opts: ComposeUpOpts|nil): ward.Cmd
---@field down fun(opts: ComposeDownOpts|nil): ward.Cmd
---@field ps fun(services: string|string[]|nil, opts: ComposePsOpts|nil): ward.Cmd
---@field logs fun(services: string|string[]|nil, opts: ComposeLogsOpts|nil): ward.Cmd
---@field build fun(services: string|string[]|nil, opts: ComposeBuildOpts|nil): ward.Cmd
---@field pull fun(services: string|string[]|nil, opts: ComposePullOpts|nil): ward.Cmd
---@field start fun(services: string|string[]|nil, opts: ComposeStartStopOpts|nil): ward.Cmd
---@field stop fun(services: string|string[]|nil, opts: ComposeStartStopOpts|nil): ward.Cmd
---@field restart fun(services: string|string[]|nil, opts: ComposeStartStopOpts|nil): ward.Cmd
---@field exec fun(service: string, cmdline: string|string[]|nil, opts: ComposeExecOpts|nil): ward.Cmd
---@field run fun(service: string, cmdline: string|string[]|nil, opts: ComposeRunOpts|nil): ward.Cmd
---@field config fun(opts: ComposeOpts|nil): ward.Cmd
---@field version fun(opts: ComposeOpts|nil): ward.Cmd
---@field raw fun(argv: string|string[], opts: ComposeOpts|nil): ward.Cmd
local Compose = {}

---@param opts ComposeOpts|nil
---@return string
local function engine_bin(opts)
	local eng = opts and opts.engine or nil
	if eng == nil or eng == "docker" then
		return "docker"
	end
	if eng == "podman" then
		return "podman"
	end
	error("invalid compose engine: " .. tostring(eng))
end

---@param args string[]
---@param opts ComposeOpts|nil
local function apply_global_opts(args, opts)
	opts = opts or {}
	if opts.project_name ~= nil then
		validate.non_empty_string(opts.project_name, "project_name")
		args[#args + 1] = "-p"
		args[#args + 1] = opts.project_name
	end
	if opts.file ~= nil then
		args_util.add_repeatable(args, opts.file, "-f", "file")
	end
	if opts.env_file ~= nil then
		args_util.add_repeatable(args, opts.env_file, "--env-file", "env_file")
	end
	if opts.profile ~= nil then
		args_util.add_repeatable(args, opts.profile, "--profile", "profile")
	end
	if opts.ansi ~= nil then
		validate.non_empty_string(opts.ansi, "ansi")
		args[#args + 1] = "--ansi"
		args[#args + 1] = opts.ansi
	end
	if opts.progress ~= nil then
		validate.non_empty_string(opts.progress, "progress")
		args[#args + 1] = "--progress"
		args[#args + 1] = opts.progress
	end
	args_util.append_extra(args, opts.extra)
end

---@param args string[]
---@param argv string|string[]|nil
local function append_argv(args, argv)
	if argv == nil then
		return
	end
	local av = args_util.normalize_string_or_array(argv, "argv")
	for _, s in ipairs(av) do
		args[#args + 1] = s
	end
end

---Low-level helper: `(<engine>) compose <subcmd> [global opts...] [argv...]`
---@param subcmd string
---@param argv string|string[]|nil
---@param opts ComposeOpts|nil
---@return ward.Cmd
function Compose.cmd(subcmd, argv, opts)
	local bin = engine_bin(opts)
	ensure.bin(bin, { label = "compose engine binary" })
	validate.non_empty_string(subcmd, "subcmd")
	local args = { bin, "compose", subcmd }
	apply_global_opts(args, opts)
	append_argv(args, argv)
	return _cmd.cmd(table.unpack(args))
end

---`(<engine>) compose up [opts...] [services...]`
---@param services string|string[]|nil
---@param opts ComposeUpOpts|nil
---@return ward.Cmd
function Compose.up(services, opts)
	local o = opts or {}
	local bin = engine_bin(o)
	ensure.bin(bin, { label = "compose engine binary" })
	local args = { bin, "compose", "up" }
	apply_global_opts(args, o)
	if o.detach then
		args[#args + 1] = "-d"
	end
	if o.build then
		args[#args + 1] = "--build"
	end
	if o.force_recreate then
		args[#args + 1] = "--force-recreate"
	end
	if o.no_recreate then
		args[#args + 1] = "--no-recreate"
	end
	if o.remove_orphans then
		args[#args + 1] = "--remove-orphans"
	end
	if o.no_start then
		args[#args + 1] = "--no-start"
	end
	if o.wait then
		args[#args + 1] = "--wait"
	end
	append_argv(args, services)
	return _cmd.cmd(table.unpack(args))
end

---`(<engine>) compose down [opts...]`
---@param opts ComposeDownOpts|nil
---@return ward.Cmd
function Compose.down(opts)
	local o = opts or {}
	local bin = engine_bin(o)
	ensure.bin(bin, { label = "compose engine binary" })
	local args = { bin, "compose", "down" }
	apply_global_opts(args, o)
	if o.remove_orphans then
		args[#args + 1] = "--remove-orphans"
	end
	if o.volumes then
		args[#args + 1] = "-v"
	end
	if o.rmi ~= nil then
		validate.non_empty_string(o.rmi, "rmi")
		args[#args + 1] = "--rmi"
		args[#args + 1] = o.rmi
	end
	if o.timeout ~= nil then
		validate.integer_min(o.timeout, "timeout", 0)
		args[#args + 1] = "-t"
		args[#args + 1] = tostring(o.timeout)
	end
	return _cmd.cmd(table.unpack(args))
end

---`(<engine>) compose ps [opts...] [services...]`
---@param services string|string[]|nil
---@param opts ComposePsOpts|nil
---@return ward.Cmd
function Compose.ps(services, opts)
	local o = opts or {}
	local bin = engine_bin(o)
	ensure.bin(bin, { label = "compose engine binary" })
	local args = { bin, "compose", "ps" }
	apply_global_opts(args, o)
	if o.all then
		args[#args + 1] = "-a"
	end
	if o.quiet then
		args[#args + 1] = "-q"
	end
	if o.status ~= nil then
		validate.non_empty_string(o.status, "status")
		args[#args + 1] = "--status"
		args[#args + 1] = o.status
	end
	if o.format ~= nil then
		validate.non_empty_string(o.format, "format")
		args[#args + 1] = "--format"
		args[#args + 1] = o.format
	end
	append_argv(args, services)
	return _cmd.cmd(table.unpack(args))
end

---`(<engine>) compose logs [opts...] [services...]`
---@param services string|string[]|nil
---@param opts ComposeLogsOpts|nil
---@return ward.Cmd
function Compose.logs(services, opts)
	local o = opts or {}
	local bin = engine_bin(o)
	ensure.bin(bin, { label = "compose engine binary" })
	local args = { bin, "compose", "logs" }
	apply_global_opts(args, o)
	if o.follow then
		args[#args + 1] = "-f"
	end
	if o.timestamps then
		args[#args + 1] = "-t"
	end
	if o.no_color then
		args[#args + 1] = "--no-color"
	end
	if o.since ~= nil then
		validate.non_empty_string(o.since, "since")
		args[#args + 1] = "--since"
		args[#args + 1] = o.since
	end
	if o["until"] ~= nil then
		validate.non_empty_string(o["until"], "until")
		args[#args + 1] = "--until"
		args[#args + 1] = o["until"]
	end
	if o.tail ~= nil then
		args[#args + 1] = "--tail"
		args[#args + 1] = tostring(o.tail)
	end
	append_argv(args, services)
	return _cmd.cmd(table.unpack(args))
end

---`(<engine>) compose build [opts...] [services...]`
---@param services string|string[]|nil
---@param opts ComposeBuildOpts|nil
---@return ward.Cmd
function Compose.build(services, opts)
	local o = opts or {}
	local bin = engine_bin(o)
	ensure.bin(bin, { label = "compose engine binary" })
	local args = { bin, "compose", "build" }
	apply_global_opts(args, o)
	if o.pull then
		args[#args + 1] = "--pull"
	end
	if o.no_cache then
		args[#args + 1] = "--no-cache"
	end
	if o.parallel then
		args[#args + 1] = "--parallel"
	end
	if o.push then
		args[#args + 1] = "--push"
	end
	append_argv(args, services)
	return _cmd.cmd(table.unpack(args))
end

---`(<engine>) compose pull [opts...] [services...]`
---@param services string|string[]|nil
---@param opts ComposePullOpts|nil
---@return ward.Cmd
function Compose.pull(services, opts)
	local o = opts or {}
	local bin = engine_bin(o)
	ensure.bin(bin, { label = "compose engine binary" })
	local args = { bin, "compose", "pull" }
	apply_global_opts(args, o)
	if o.include_deps then
		args[#args + 1] = "--include-deps"
	end
	if o.ignore_failures then
		args[#args + 1] = "--ignore-pull-failures"
	end
	append_argv(args, services)
	return _cmd.cmd(table.unpack(args))
end

---`(<engine>) compose start [services...]`
---@param services string|string[]|nil
---@param opts ComposeStartStopOpts|nil
---@return ward.Cmd
function Compose.start(services, opts)
	return Compose.cmd("start", services, opts)
end

---`(<engine>) compose stop [opts...] [services...]`
---@param services string|string[]|nil
---@param opts ComposeStartStopOpts|nil
---@return ward.Cmd
function Compose.stop(services, opts)
	local o = opts or {}
	local bin = engine_bin(o)
	ensure.bin(bin, { label = "compose engine binary" })
	local args = { bin, "compose", "stop" }
	apply_global_opts(args, o)
	if o.timeout ~= nil then
		validate.integer_min(o.timeout, "timeout", 0)
		args[#args + 1] = "-t"
		args[#args + 1] = tostring(o.timeout)
	end
	append_argv(args, services)
	return _cmd.cmd(table.unpack(args))
end

---`(<engine>) compose restart [opts...] [services...]`
---@param services string|string[]|nil
---@param opts ComposeStartStopOpts|nil
---@return ward.Cmd
function Compose.restart(services, opts)
	local o = opts or {}
	local bin = engine_bin(o)
	ensure.bin(bin, { label = "compose engine binary" })
	local args = { bin, "compose", "restart" }
	apply_global_opts(args, o)
	if o.timeout ~= nil then
		validate.integer_min(o.timeout, "timeout", 0)
		args[#args + 1] = "-t"
		args[#args + 1] = tostring(o.timeout)
	end
	append_argv(args, services)
	return _cmd.cmd(table.unpack(args))
end

---`(<engine>) compose exec [opts...] <service> [cmd...]`
---@param service string
---@param cmdline string|string[]|nil
---@param opts ComposeExecOpts|nil
---@return ward.Cmd
function Compose.exec(service, cmdline, opts)
	local o = opts or {}
	local bin = engine_bin(o)
	ensure.bin(bin, { label = "compose engine binary" })
	validate.non_empty_string(service, "service")
	local args = { bin, "compose", "exec" }
	apply_global_opts(args, o)
	if o.detach then
		args[#args + 1] = "-d"
	end
	if o.interactive then
		args[#args + 1] = "-i"
	end
	if o.tty then
		args[#args + 1] = "-t"
	end
	if o.user ~= nil then
		validate.non_empty_string(o.user, "user")
		args[#args + 1] = "-u"
		args[#args + 1] = o.user
	end
	if o.workdir ~= nil then
		validate.non_empty_string(o.workdir, "workdir")
		args[#args + 1] = "-w"
		args[#args + 1] = o.workdir
	end
	if o.env ~= nil then
		args_util.add_repeatable(args, o.env, "-e", "env")
	end
	args[#args + 1] = service
	append_argv(args, cmdline)
	return _cmd.cmd(table.unpack(args))
end

---`(<engine>) compose run [opts...] <service> [cmd...]`
---@param service string
---@param cmdline string|string[]|nil
---@param opts ComposeRunOpts|nil
---@return ward.Cmd
function Compose.run(service, cmdline, opts)
	local o = opts or {}
	local bin = engine_bin(o)
	ensure.bin(bin, { label = "compose engine binary" })
	validate.non_empty_string(service, "service")
	local args = { bin, "compose", "run" }
	apply_global_opts(args, o)
	if o.detach then
		args[#args + 1] = "-d"
	end
	if o.rm then
		args[#args + 1] = "--rm"
	end
	if o.no_deps then
		args[#args + 1] = "--no-deps"
	end
	if o.service_ports then
		args[#args + 1] = "--service-ports"
	end
	if o.name ~= nil then
		validate.non_empty_string(o.name, "name")
		args[#args + 1] = "--name"
		args[#args + 1] = o.name
	end
	if o.entrypoint ~= nil then
		validate.non_empty_string(o.entrypoint, "entrypoint")
		args[#args + 1] = "--entrypoint"
		args[#args + 1] = o.entrypoint
	end
	if o.user ~= nil then
		validate.non_empty_string(o.user, "user")
		args[#args + 1] = "-u"
		args[#args + 1] = o.user
	end
	if o.workdir ~= nil then
		validate.non_empty_string(o.workdir, "workdir")
		args[#args + 1] = "-w"
		args[#args + 1] = o.workdir
	end
	if o.env ~= nil then
		args_util.add_repeatable(args, o.env, "-e", "env")
	end
	if o.publish ~= nil then
		args_util.add_repeatable(args, o.publish, "-p", "publish")
	end
	if o.volume ~= nil then
		args_util.add_repeatable(args, o.volume, "-v", "volume")
	end
	args[#args + 1] = service
	append_argv(args, cmdline)
	return _cmd.cmd(table.unpack(args))
end

---`(<engine>) compose config`
---@param opts ComposeOpts|nil
---@return ward.Cmd
function Compose.config(opts)
	return Compose.cmd("config", nil, opts)
end

---`(<engine>) compose version`
---@param opts ComposeOpts|nil
---@return ward.Cmd
function Compose.version(opts)
	return Compose.cmd("version", nil, opts)
end

---Low-level escape hatch.
---Builds: `(<engine>) compose <argv...>`
---@param argv string|string[]
---@param opts ComposeOpts|nil
---@return ward.Cmd
function Compose.raw(argv, opts)
	local bin = engine_bin(opts)
	ensure.bin(bin, { label = "compose engine binary" })
	local args = { bin, "compose" }
	apply_global_opts(args, opts)
	append_argv(args, argv)
	return _cmd.cmd(table.unpack(args))
end

return {
	Compose = Compose,
}
