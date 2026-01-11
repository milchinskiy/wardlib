# compose

Unified wrapper for Compose commands.

This module targets one of two engines:

- Docker Compose v2 plugin: `docker compose ...` (default)
- Podman Compose plugin: `podman compose ...` (when `engine = "podman"`)

> This wrapper constructs a `ward.process.cmd(...)` invocation; it does not
> parse output.

## Import

```lua
local Compose = require("app.compose").Compose
```

## Engine selection

The `engine` option selects which binary is used:

- `engine = nil` or `engine = "docker"` → `docker compose ...`
- `engine = "podman"` → `podman compose ...`

## Global options

`ComposeOpts` fields are applied to all subcommands:

- `project_name` (`-p`)
- `file` (`-f`, repeatable)
- `env_file` (`--env-file`, repeatable)
- `profile` (`--profile`, repeatable)
- `ansi` (`--ansi`)
- `progress` (`--progress`)
- `extra` (appended after modeled options)

## API

### Common helpers

- `Compose.cmd(subcmd, argv, opts)`
- `Compose.raw(argv, opts)`

### Lifecycle

- `Compose.up(services, opts)`
- `Compose.down(opts)`
- `Compose.ps(services, opts)`
- `Compose.logs(services, opts)`
- `Compose.start(services, opts)`
- `Compose.stop(services, opts)`
- `Compose.restart(services, opts)`

### Images

- `Compose.build(services, opts)`
- `Compose.pull(services, opts)`

### Run/exec

- `Compose.exec(service, cmdline, opts)`
- `Compose.run(service, cmdline, opts)`

### Introspection

- `Compose.config(opts)`
- `Compose.version(opts)`

## Examples

```lua
local Compose = require("app.compose").Compose

-- docker compose -f compose.yml up -d
local cmd1 = Compose.up(nil, { file = "compose.yml", detach = true })

-- podman compose down --remove-orphans
local cmd2 = Compose.down({ engine = "podman", remove_orphans = true })

-- docker compose exec -w /w -e A=1 web sh -lc 'id'
local cmd3 = Compose.exec("web", { "sh", "-lc", "id" }, { workdir = "/w", env = "A=1" })
```
