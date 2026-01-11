# docker

`docker` is a container runtime and image management CLI.

> This wrapper constructs a `ward.process.cmd(...)` invocation; it does not
> parse output.

## Import

```lua
local Docker = require("app.docker").Docker
```

## API

### `Docker.run(image, cmdline, opts)`

Builds: `docker run <opts...> <image> [cmd...]`

Modeled run options include `--rm`, `--name`, `-e/--env`, `--env-file`, `-p`,
`-v`, `--network`, capabilities, and more.

### `Docker.exec(container, cmdline, opts)`

Builds: `docker exec <opts...> <container> [cmd...]`

### `Docker.build(context, opts)`

Builds: `docker build <opts...> <context>`

Supports `-t`, `-f`, `--build-arg`, `--no-cache`, `--target`, `--platform`, etc.

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
  - For security, the wrapper does **not** accept a password string; prefer `password_stdin=true`.
- `Docker.logout(registry, opts)` → `docker logout ...`

### `Docker.raw(argv, opts)`

Builds: `docker <argv...>`

Use this when you need a docker feature not modeled in the structured opts.

## Repeatable options

Repeatable fields (like `env`, `publish`, `volume`, `filter`, etc.) accept `string|string[]`.
For example:

```lua
Docker.run("alpine:3", "env", {
  env = { "A=1", "B=2" },
  publish = { "8080:80", "8443:443" },
})
```

## Examples

```lua
local Docker = require("app.docker").Docker

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
```
