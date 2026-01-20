# podman

`podman` is a daemonless container engine. It can operate **rootless** (recommended)
or with elevated privileges depending on your host configuration.

> This module constructs `ward.process.cmd(...)` invocations; it does not parse output.
> consumers can use `wardlib.tools.out` (or their own parsing) on the `:output()`
> result.

## Import

```lua
local Podman = require("wardlib.app.podman").Podman
```

## Privilege model

- Rootless Podman: run normally as your user.
- System/root Podman: if your workflow requires root (for certain storage drivers,
  networking setups, or host administration), scope privilege escalation explicitly
  via `wardlib.tools.with`.

```lua
local with = require("wardlib.tools.with")
local Podman = require("wardlib.app.podman").Podman

with.with(with.middleware.sudo(), function()
  Podman.ps({ all = true }):run()
end)
```

## API

### `Podman.bin`

Executable name or path (default: `"podman"`).

### `Podman.cmd(subcmd, argv)`

Generic helper: builds `podman <subcmd> [argv...]`.

### `Podman.run(image, cmdline, opts)`

Builds: `podman run <opts...> <image> [cmd...]`.

### `Podman.exec(container, cmdline, opts)`

Builds: `podman exec <opts...> <container> [cmd...]`.

### `Podman.build(context, opts)`

Builds: `podman build <opts...> <context>`.

If `context` is `nil`, the wrapper uses `"."`.

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

- `Podman.login(registry, opts)` → `podman login [opts...] [registry]`
  - For security, the wrapper does **not** accept a password string; prefer `password_stdin=true`.
- `Podman.logout(registry, opts)` → `podman logout [registry]`

### `Podman.raw(argv, opts)`

Low-level escape hatch. Builds: `podman <extra...> <argv...>`.

Use this when you need a Podman feature not modeled by the structured helpers.

## Options

Repeatable fields accept `string|string[]`.

### `PodmanRunOpts`

- `detach: boolean?` → `-d`
- `interactive: boolean?` → `-i`
- `tty: boolean?` → `-t`
- `rm: boolean?` → `--rm`
- `name: string?` → `--name <name>`
- `hostname: string?` → `--hostname <hostname>`
- `workdir: string?` → `-w <dir>`
- `user: string?` → `-u <user>`
- `entrypoint: string?` → `--entrypoint <entrypoint>`
- `env: string|string[]?` → `-e <k=v>` (repeatable)
- `env_file: string|string[]?` → `--env-file <file>` (repeatable)
- `publish: string|string[]?` → `-p <host:container>` (repeatable)
- `volume: string|string[]?` → `-v <host:container>` (repeatable)
- `network: string?` → `--network <net>`
- `add_host: string|string[]?` → `--add-host <host:ip>` (repeatable)
- `label: string|string[]?` → `--label <k=v>` (repeatable)
- `privileged: boolean?` → `--privileged`
- `cap_add: string|string[]?` → `--cap-add <cap>` (repeatable)
- `cap_drop: string|string[]?` → `--cap-drop <cap>` (repeatable)
- `platform: string?` → `--platform <platform>`
- `pull: string?` → `--pull <policy>`
- `extra: string[]?` → extra argv appended after modeled options

### `PodmanExecOpts`

- `detach: boolean?` → `-d`
- `interactive: boolean?` → `-i`
- `tty: boolean?` → `-t`
- `user: string?` → `-u <user>`
- `workdir: string?` → `-w <dir>`
- `env: string|string[]?` → `-e <k=v>` (repeatable)
- `extra: string[]?`

### `PodmanBuildOpts`

- `tag: string|string[]?` → `-t <tag>` (repeatable)
- `file: string?` → `-f <containerfile>`
- `build_arg: string|string[]?` → `--build-arg <k=v>` (repeatable)
- `target: string?` → `--target <stage>`
- `platform: string?` → `--platform <platform>`
- `pull: boolean?` → `--pull`
- `no_cache: boolean?` → `--no-cache`
- `layers: boolean?` → `--layers`
- `format: string?` → `--format <format>`
- `extra: string[]?`

### `PodmanPsOpts`

- `all: boolean?` → `-a`
- `quiet: boolean?` → `-q`
- `no_trunc: boolean?` → `--no-trunc`
- `latest: boolean?` → `-l`
- `last: integer?` → `-n <n>`
- `size: boolean?` → `-s`
- `format: string?` → `--format <fmt>`
- `filter: string|string[]?` → `--filter <filter>` (repeatable)
- `extra: string[]?`

### `PodmanImagesOpts`

- `all: boolean?` → `-a`
- `quiet: boolean?` → `-q`
- `no_trunc: boolean?` → `--no-trunc`
- `digests: boolean?` → `--digests`
- `format: string?` → `--format <fmt>`
- `filter: string|string[]?` → `--filter <filter>` (repeatable)
- `extra: string[]?`

### `PodmanLogsOpts`

- `follow: boolean?` → `-f`
- `timestamps: boolean?` → `-t`
- `since: string?` → `--since <time>`
- `until: string?` → `--until <time>`
- `tail: string|integer?` → `--tail <n|all>`
- `extra: string[]?`

### `PodmanRmOpts`

- `force: boolean?` → `-f`
- `volumes: boolean?` → `-v`
- `extra: string[]?`

### `PodmanRmiOpts`

- `force: boolean?` → `-f`
- `extra: string[]?`

### `PodmanStopOpts`

- `time: integer?` → `-t <seconds>`
- `extra: string[]?`

### `PodmanInspectOpts`

- `format: string?` → `-f <format>`
- `size: boolean?` → `-s`
- `type: string?` → `--type <type>`
- `extra: string[]?`

### `PodmanLoginOpts`

- `username: string?` → `-u <user>`
- `password_stdin: boolean?` → `--password-stdin`
- `extra: string[]?`

## Examples

### Run and remove a container

```lua
local Podman = require("wardlib.app.podman").Podman

-- podman run --rm -e A=1 -p 8080:80 alpine:3 sh -lc 'echo ok'
Podman.run("alpine:3", { "sh", "-lc", "echo ok" }, {
  rm = true,
  env = "A=1",
  publish = "8080:80",
}):run()
```

### Build an image

```lua
local Podman = require("wardlib.app.podman").Podman

-- podman build -t myimg:dev -f Containerfile --layers .
Podman.build(".", {
  tag = "myimg:dev",
  file = "Containerfile",
  layers = true,
}):run()
```

### Inspect and parse JSON output

`podman inspect` prints JSON by default (an array). Parse it using `wardlib.tools.out`:

```lua
local Podman = require("wardlib.app.podman").Podman
local out = require("wardlib.tools.out")

local data = out.cmd(Podman.inspect("myctr"))
  :label("podman inspect myctr")
  :json()

-- data is usually an array; take first element
local obj = data[1]
local image = obj.ImageName
```

### Tail logs

```lua
local Podman = require("wardlib.app.podman").Podman

Podman.logs("myctr", { follow = true, tail = 100 }):run()
```

### Login with `--password-stdin`

```lua
local proc = require("ward.process")
local Podman = require("wardlib.app.podman").Podman

-- printf '%s' "$TOKEN" | podman login --password-stdin -u myuser registry.example.com
local feeder = proc.cmd("printf", "%s", "mytoken")
local cmd = Podman.login("registry.example.com", {
  username = "myuser",
  password_stdin = true,
})

(feeder | cmd):run()
```
