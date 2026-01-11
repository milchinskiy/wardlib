# podman

`podman` is a daemonless container engine.

> This wrapper constructs a `ward.process.cmd(...)` invocation; it does
> not parse output.

## Import

```lua
local Podman = require("app.podman").Podman
```

## API

### `Podman.run(image, cmdline, opts)`

Builds: `podman run <opts...> <image> [cmd...]`

Modeled run options include `--rm`, `--name`, `-e/--env`, `--env-file`, `-p`,
`-v`, `--network`, capabilities, and more.

### `Podman.exec(container, cmdline, opts)`

Builds: `podman exec <opts...> <container> [cmd...]`

### `Podman.build(context, opts)`

Builds: `podman build <opts...> <context>`

Supports `-t`, `-f`, `--build-arg`, `--no-cache`, `--target`, `--platform`,
plus podman-specific `--layers` and `--format`.

### `Podman.pull(image, opts)` / `Podman.push(image, opts)`

Builds: `podman pull <image>` and `podman push <image>`.

### `Podman.ps(opts)` / `Podman.images(opts)`

Builds: `podman ps <opts...>` and `podman images <opts...>`.

### `Podman.logs(container, opts)`

Builds: `podman logs <opts...> <container>`.

### Lifecycle helpers

- `Podman.rm(containers, opts)` → `podman rm ...`
- `Podman.rmi(images, opts)` → `podman rmi ...`
- `Podman.start(containers, opts)` → `podman start ...`
- `Podman.stop(containers, opts)` → `podman stop ...`
- `Podman.restart(containers, opts)` → `podman restart ...`
- `Podman.inspect(targets, opts)` → `podman inspect ...`
- `Podman.tag(source, target, opts)` → `podman tag ...`

### Auth helpers

- `Podman.login(registry, opts)` → `podman login ...`
  - For security, the wrapper does **not** accept a password string; prefer
  `password_stdin=true`.
- `Podman.logout(registry, opts)` → `podman logout ...`

### `Podman.raw(argv, opts)`

Builds: `podman <argv...>`

Use this when you need a podman feature not modeled in the structured opts.

## Repeatable options

Repeatable fields (like `env`, `publish`, `volume`, `filter`, etc.) accept `string|string[]`.

## Examples

```lua
local Podman = require("app.podman").Podman

-- podman run --rm -e A=1 -p 8080:80 alpine:3 sh -lc 'echo ok'
local cmd1 = Podman.run("alpine:3", { "sh", "-lc", "echo ok" }, {
  rm = true,
  env = "A=1",
  publish = "8080:80",
})

-- podman build -t myimg:dev -f Containerfile --layers .
local cmd2 = Podman.build(".", {
  tag = "myimg:dev",
  file = "Containerfile",
  layers = true,
})

-- podman ps -a --filter status=running
local cmd3 = Podman.ps({ all = true, filter = "status=running" })

-- podman logs -f --tail 100 myctr
local cmd4 = Podman.logs("myctr", { follow = true, tail = 100 })
```
