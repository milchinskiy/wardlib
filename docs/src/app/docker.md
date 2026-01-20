# docker

`docker` is a container runtime and image management CLI.

> This module constructs `ward.process.cmd(...)` invocations; it does not parse output.
> consumers can use `wardlib.tools.out` (or their own parsing) on the `:output()`
> result.

## Import

```lua
local Docker = require("wardlib.app.docker").Docker
```

## Running with elevated privileges

Many Linux distributions allow non-root access to Docker via the `docker` group.
If you need to run `docker` under privilege escalation,
use `wardlib.tools.with` middleware.

```lua
local with = require("wardlib.tools.with")
local Docker = require("wardlib.app.docker").Docker

with.with(with.middleware.sudo(), function()
  Docker.ps({ all = true }):run()
end)
```

## API

### `Docker.cmd(subcmd, argv)`

Builds: `docker <subcmd> [argv...]`

### `Docker.run(image, cmdline, opts)`

Builds: `docker run <opts...> <image> [cmd...]`

### `Docker.exec(container, cmdline, opts)`

Builds: `docker exec <opts...> <container> [cmd...]`

### `Docker.build(context, opts)`

Builds: `docker build <opts...> <context>`

### `Docker.pull(image, opts)` / `Docker.push(image, opts)`

Builds: `docker pull <image>` and `docker push <image>`.

### `Docker.ps(opts)` / `Docker.images(opts)`

Builds: `docker ps <opts...>` and `docker images <opts...>`.

### `Docker.logs(container, opts)`

Builds: `docker logs <opts...> <container>`.

### Lifecycle helpers

- `Docker.rm(containers, opts)` → `docker rm ...`
- `Docker.rmi(images, opts)` → `docker rmi ...`
- `Docker.start(containers, opts)` → `docker start ...`
- `Docker.stop(containers, opts)` → `docker stop ...`
- `Docker.restart(containers, opts)` → `docker restart ...`
- `Docker.inspect(targets, opts)` → `docker inspect ...`
- `Docker.tag(source, target, opts)` → `docker tag ...`

### Auth helpers

- `Docker.login(registry, opts)` → `docker login ...`
  - For security, this wrapper does not accept a password string.
  Prefer `password_stdin=true` and supply stdin via your own pipeline/middleware.
- `Docker.logout(registry, opts)` → `docker logout ...`

### `Docker.raw(argv, opts)`

Builds: `docker <argv...>`

Use this when you need a docker feature not modeled in the structured option types.

All functions return a `ward.process.cmd(...)` object.

## Options

Repeatable fields (like `env`, `publish`, `volume`, `filter`, etc.) accept `string|string[]`.

### `DockerRunOpts`

- Session: `detach` (`-d`), `interactive` (`-i`), `tty` (`-t`), `rm` (`--rm`)
- Identity: `name` (`--name`), `hostname` (`--hostname`), `workdir` (`-w`),
`user` (`-u`), `entrypoint` (`--entrypoint`)
- Environment: `env` (`-e`, repeatable), `env_file` (`--env-file`, repeatable)
- Networking/storage: `publish` (`-p`, repeatable), `volume` (`-v`, repeatable),
`network` (`--network`), `add_host` (`--add-host`, repeatable)
- Labels/caps: `label` (`--label`, repeatable), `privileged` (`--privileged`),
`cap_add` (`--cap-add`, repeatable), `cap_drop` (`--cap-drop`, repeatable)
- Platform/pull: `platform` (`--platform`), `pull` (`--pull <policy>`)
- Escape hatch: `extra`

### `DockerExecOpts`

- `detach` (`-d`), `interactive` (`-i`), `tty` (`-t`)
- `user` (`-u`), `workdir` (`-w`)
- `env` (`-e`, repeatable)
- Escape hatch: `extra`

### `DockerBuildOpts`

- `tag` (`-t`, repeatable), `file` (`-f`)
- `build_arg` (`--build-arg`, repeatable)
- `target` (`--target`), `platform` (`--platform`)
- `pull` (`--pull`), `no_cache` (`--no-cache`), `progress` (`--progress`)
- Escape hatch: `extra`

### `DockerPsOpts`

- `all` (`-a`), `quiet` (`-q`), `no_trunc` (`--no-trunc`), `latest` (`-l`),
`size` (`-s`)
- `last` (`-n <n>`), `format` (`--format <fmt>`)
- `filter` (`--filter`, repeatable)
- Escape hatch: `extra`

### `DockerImagesOpts`

- `all` (`-a`), `quiet` (`-q`), `no_trunc` (`--no-trunc`), `digests` (`--digests`)
- `format` (`--format <fmt>`)
- `filter` (`--filter`, repeatable)
- Escape hatch: `extra`

### `DockerLogsOpts`

- `follow` (`-f`), `timestamps` (`-t`), `details` (`--details`)
- `since` (`--since`), `until` (`--until`), `tail` (`--tail <n|all>`)
- Escape hatch: `extra`

### Other option types

- `DockerRmOpts`: `force` (`-f`), `volumes` (`-v`), `link` (`-l`), `extra`
- `DockerRmiOpts`: `force` (`-f`), `no_prune` (`--no-prune`), `extra`
- `DockerStopOpts`: `time` (`-t <seconds>`), `extra`
- `DockerInspectOpts`: `format` (`-f <format>`), `size` (`-s`),
`type` (`--type`), `extra`
- `DockerLoginOpts`: `username` (`-u <user>`),
`password_stdin` (`--password-stdin`), `extra`

## Examples

```lua
local Docker = require("wardlib.app.docker").Docker

-- docker run --rm -e A=1 -p 8080:80 alpine:3 sh -lc 'echo ok'
local cmd1 = Docker.run("alpine:3", { "sh", "-lc", "echo ok" }, {
  rm = true,
  env = "A=1",
  publish = "8080:80",
})

-- docker build -t myimg:dev -f Dockerfile --build-arg A=1 .
local cmd2 = Docker.build(".", {
  tag = "myimg:dev",
  file = "Dockerfile",
  build_arg = "A=1",
})

-- docker ps -a --filter status=running
local cmd3 = Docker.ps({ all = true, filter = "status=running" })

-- docker logs -f --tail 100 myctr
local cmd4 = Docker.logs("myctr", { follow = true, tail = 100 })

local out = require("wardlib.tools.out")

-- docker inspect returns JSON; parse it
local inspect_res = Docker.inspect("myctr"):output()
local info = out.res(inspect_res):label("docker inspect myctr"):json()
-- `info` is typically an array of objects

-- Run docker under sudo (if needed)
local with = require("wardlib.tools.with")
with.with(with.middleware.sudo(), function()
  Docker.images({ all = true }):run()
end)
```
