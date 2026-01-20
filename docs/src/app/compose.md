# compose

Unified wrapper for Compose commands.

This module targets one of two engines:

- Docker Compose v2 plugin: `docker compose ...` (default)
- Podman Compose plugin: `podman compose ...` (when `engine = "podman"`)

> This module constructs `ward.process.cmd(...)` invocations; it does not parse output.
> consumers can use `wardlib.tools.out` (or their own parsing) on the `:output()`
> result.

## Import

```lua
local Compose = require("wardlib.app.compose").Compose
```

## Privilege escalation

Compose typically runs as the current user. If your engine requires elevated
privileges on your system, wrap the returned command with `wardlib.tools.with`.

```lua
local w = require("wardlib.tools.with")
local Compose = require("wardlib.app.compose").Compose

w.with(w.middleware.sudo(), Compose.version()):run()
```

## Engine selection

The `engine` option selects which binary is used:

- `engine = nil` or `engine = "docker"` → `docker compose ...`
- `engine = "podman"` → `podman compose ...`

## API

All functions return a `ward.process.cmd(...)` object.

### Low-level helpers

#### `Compose.cmd(subcmd, argv, opts)`

Builds: `(<engine>) compose <subcmd> <global opts...> <argv...>`

- `subcmd: string`
- `argv: string|string[]|nil` — appended after modeled options.
- `opts: ComposeOpts|nil`

#### `Compose.raw(argv, opts)`

Builds: `(<engine>) compose <global opts...> <argv...>`

### Lifecycle

#### `Compose.up(services, opts)`

Builds: `(<engine>) compose up <global opts...> <up opts...> [services...]`

#### `Compose.down(opts)`

Builds: `(<engine>) compose down <global opts...> <down opts...>`

#### `Compose.ps(services, opts)`

Builds: `(<engine>) compose ps <global opts...> <ps opts...> [services...]`

#### `Compose.logs(services, opts)`

Builds: `(<engine>) compose logs <global opts...> <logs opts...> [services...]`

#### `Compose.start(services, opts)` / `Compose.stop(services, opts)` / `Compose.restart(services, opts)`

Builds: `(<engine>) compose <start|stop|restart> <global opts...> <start/stop opts...> [services...]`

### Images

#### `Compose.build(services, opts)`

Builds: `(<engine>) compose build <global opts...> <build opts...> [services...]`

#### `Compose.pull(services, opts)`

Builds: `(<engine>) compose pull <global opts...> <pull opts...> [services...]`

### Run and exec

#### `Compose.exec(service, cmdline, opts)`

Builds: `(<engine>) compose exec <global opts...> <exec opts...> <service> <cmdline...>`

- `service: string`
- `cmdline: string|string[]|nil` — command inside the container; when `nil`, exec opens the service default command.

#### `Compose.run(service, cmdline, opts)`

Builds: `(<engine>) compose run <global opts...> <run opts...> <service> <cmdline...>`

### Introspection

#### `Compose.config(opts)`

Builds: `(<engine>) compose config <global opts...>`

#### `Compose.version(opts)`

Builds: `(<engine>) compose version <global opts...>`

## Options

### `ComposeOpts` (global options)

Applied to all subcommands:

- `engine: "docker"|"podman"|nil` — select binary.
- `project_name: string|nil` — `-p <name>`.
- `file: string|string[]|nil` — `-f <file>` repeated.
- `env_file: string|string[]|nil` — `--env-file <file>` repeated.
- `profile: string|string[]|nil` — `--profile <name>` repeated.
- `ansi: string|nil` — `--ansi <never|always|auto>`.
- `progress: string|nil` — `--progress <auto|tty|plain|quiet>`.
- `extra: string[]|nil` — pass-through args appended after modeled global options.

### `ComposeUpOpts`

Extends `ComposeOpts` with:

- `detach` (`-d`)
- `build` (`--build`)
- `force_recreate` (`--force-recreate`)
- `no_recreate` (`--no-recreate`)
- `remove_orphans` (`--remove-orphans`)
- `no_start` (`--no-start`)
- `wait` (`--wait`)

### `ComposeDownOpts`

Extends `ComposeOpts` with:

- `remove_orphans` (`--remove-orphans`)
- `volumes` (`-v`)
- `rmi: string|nil` (`--rmi <all|local>`)
- `timeout: integer|nil` (`-t <seconds>`)

### `ComposePsOpts`

Extends `ComposeOpts` with:

- `all` (`-a`)
- `quiet` (`-q`)
- `status: string|nil` (`--status <running|paused|exited|created|restarting|removing|dead>`)
- `format: string|nil` (`--format <fmt>`)

### `ComposeLogsOpts`

Extends `ComposeOpts` with:

- `follow` (`-f`)
- `timestamps` (`-t`)
- `tail: string|integer|nil` (`--tail <n|all>`)
- `no_color` (`--no-color`)
- `since: string|nil` (`--since <time>`)
- `until: string|nil` (`--until <time>`)

### `ComposeBuildOpts`

Extends `ComposeOpts` with:

- `pull` (`--pull`)
- `no_cache` (`--no-cache`)
- `parallel` (`--parallel`)
- `push` (`--push`)

### `ComposePullOpts`

Extends `ComposeOpts` with:

- `include_deps` (`--include-deps`)
- `ignore_failures` (`--ignore-pull-failures`)

### `ComposeStartStopOpts`

Extends `ComposeOpts` with:

- `timeout: integer|nil` (`-t <seconds>`)

### `ComposeExecOpts`

Extends `ComposeOpts` with:

- `detach` (`-d`)
- `interactive` (`-i`)
- `tty` (`-t`)
- `user: string|nil` (`-u <user>`)
- `workdir: string|nil` (`-w <dir>`)
- `env: string|string[]|nil` (`-e <k=v>` repeatable)

### `ComposeRunOpts`

Extends `ComposeOpts` with:

- `detach` (`-d`)
- `rm` (`--rm`)
- `name: string|nil` (`--name <name>`)
- `entrypoint: string|nil` (`--entrypoint <entrypoint>`)
- `user: string|nil` (`-u <user>`)
- `workdir: string|nil` (`-w <dir>`)
- `env: string|string[]|nil` (`-e <k=v>` repeatable)
- `publish: string|string[]|nil` (`-p <host:container>` repeatable)
- `volume: string|string[]|nil` (`-v <host:container>` repeatable)
- `no_deps` (`--no-deps`)
- `service_ports` (`--service-ports`)

## Examples

### Bring up a project in detached mode

```lua
local Compose = require("wardlib.app.compose").Compose

-- docker compose -f compose.yml up -d
local cmd = Compose.up(nil, { file = "compose.yml", detach = true })
```

### Use podman engine

```lua
local Compose = require("wardlib.app.compose").Compose

-- podman compose down --remove-orphans
local cmd = Compose.down({ engine = "podman", remove_orphans = true })
```

### Exec with environment and workdir

```lua
local Compose = require("wardlib.app.compose").Compose

-- docker compose exec -w /w -e A=1 web sh -lc 'id'
local cmd = Compose.exec("web", { "sh", "-lc", "id" }, { workdir = "/w", env = "A=1" })
```

### Parse `compose config` output as text

```lua
local Compose = require("wardlib.app.compose").Compose
local out = require("wardlib.tools.out")

local res = Compose.config({ file = "compose.yml" }):output()
local yaml_text = out.res(res):ok():text()
```

### Parse `compose ps --format` when supported

Some Compose versions support JSON formatting via `--format json`.

```lua
local Compose = require("wardlib.app.compose").Compose
local out = require("wardlib.tools.out")

local res = Compose.ps(nil, { format = "json" }):output()
local data = out.res(res):ok():json()
```
