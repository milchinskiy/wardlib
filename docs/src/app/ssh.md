# ssh / scp

`wardlib.app.ssh` is a thin wrapper around OpenSSH `ssh` and `scp`.

> This module constructs `ward.process.cmd(...)` invocations; it does not parse output.
> consumers can use `wardlib.tools.out` (or their own parsing) on the `:output()`
> result.

Notes:

- `Ssh.exec()` accepts a remote command either as a **single string**
(passed as-is) or as a **string array** (appended as individual argv items).
- Use [`wardlib.tools.out`](../tools/out.md) to parse stdout/stderr.

## Import

```lua
local Ssh = require("wardlib.app.ssh").Ssh
```

## API

### `Ssh.target(host, opts)`

Builds a target string:

- `host` (default)
- `user@host` when `opts.user` is provided

### `Ssh.remote(host, path, opts)`

Builds a remote scp path string:

- `host:/path`
- `user@host:/path` when `opts.user` is provided

### `Ssh.exec(host, remote, opts)`

Builds: `ssh <common-opts...> <target> [remote...]`

- If `remote` is `nil`, builds an interactive session.
- If `remote` is a string, it is passed as a single argument.
- If `remote` is a string array, items are appended as argv.

### `Ssh.scp(src, dst, opts)`

Builds: `scp <common-opts...> <scp-opts...> <src> <dst>`

### `Ssh.copy_to(host, local_path, remote_path, opts)`

Convenience for local → remote:

Builds: `scp ... <local_path> <user@host:remote_path>`

### `Ssh.copy_from(host, remote_path, local_path, opts)`

Convenience for remote → local:

Builds: `scp ... <user@host:remote_path> <local_path>`

## Options

### `SshCommonOpts`

- `user: string?` — username (prepended as `user@host`)
- `port: integer?` — port (`ssh -p`, `scp -P`)
- `identity_file: string?` — identity file (`-i <path>`)
- `batch: boolean?` — `-o BatchMode=yes`
- `strict_host_key_checking: boolean|string?` — `-o StrictHostKeyChecking=<...>`
  - `true` → `yes`, `false` → `no`, or pass a string such as `"accept-new"`
- `known_hosts_file: string?` — `-o UserKnownHostsFile=<path>`
- `connect_timeout: integer?` — `-o ConnectTimeout=<seconds>`
- `extra: string[]?` — extra argv items appended before host/paths

### `ScpOpts` (extends `SshCommonOpts`)

- `recursive: boolean?` — `-r`
- `preserve_times: boolean?` — `-p`
- `compress: boolean?` — `-C`
- `quiet: boolean?` — `-q`

## Examples

### Interactive SSH session (with identity + port)

```lua
local Ssh = require("wardlib.app.ssh").Ssh

-- Equivalent to: ssh -p 2222 -i ~/.ssh/id_ed25519 me@example.com
local cmd = Ssh.exec("example.com", nil, {
  user = "me",
  port = 2222,
  identity_file = "~/.ssh/id_ed25519",
})

-- cmd:run()
```

### Run a remote command (array form)

```lua
local Ssh = require("wardlib.app.ssh").Ssh

-- Equivalent to: ssh me@example.com systemctl --user status pipewire.service
local cmd = Ssh.exec("example.com", { "systemctl", "--user", "status", "pipewire.service" }, {
  user = "me",
})
```

### Capture stdout from a remote command

```lua
local Ssh = require("wardlib.app.ssh").Ssh
local out = require("wardlib.tools.out")

local hostname = out.cmd(Ssh.exec("example.com", { "hostname" }, { user = "me", batch = true }))
  :label("ssh hostname")
  :trim()
  :line()

-- hostname is a single line string
```

### Hardened non-interactive connection (BatchMode + host key policy)

```lua
local Ssh = require("wardlib.app.ssh").Ssh

-- Equivalent to:
-- ssh \
--   -o BatchMode=yes \
--   -o StrictHostKeyChecking=accept-new \
--   -o UserKnownHostsFile=/tmp/known_hosts \
--   -o ConnectTimeout=5 \
--   me@example.com 'uname -a'
local cmd = Ssh.exec("example.com", "uname -a", {
  user = "me",
  batch = true,
  strict_host_key_checking = "accept-new",
  known_hosts_file = "/tmp/known_hosts",
  connect_timeout = 5,
})
```

### Copy local → remote (scp)

```lua
local Ssh = require("wardlib.app.ssh").Ssh

-- Equivalent to: scp -P 2200 -C ./build.tar.gz me@example.com:/tmp/build.tar.gz
local cmd = Ssh.copy_to("example.com", "./build.tar.gz", "/tmp/build.tar.gz", {
  user = "me",
  port = 2200,
  compress = true,
})
```

### Copy remote → local (scp)

```lua
local Ssh = require("wardlib.app.ssh").Ssh

-- Equivalent to: scp -P 2200 me@example.com:/var/log/syslog ./syslog
local cmd = Ssh.copy_from("example.com", "/var/log/syslog", "./syslog", {
  user = "me",
  port = 2200,
})
```

### Use `Ssh.scp` directly (recursive directory copy)

```lua
local Ssh = require("wardlib.app.ssh").Ssh

-- Equivalent to: scp -r ./dist me@example.com:/srv/app/dist
local cmd = Ssh.scp("./dist", "me@example.com:/srv/app/dist", {
  recursive = true,
})
```

### Advanced flags via `extra`

```lua
local Ssh = require("wardlib.app.ssh").Ssh

-- Equivalent to: ssh -vv -o LogLevel=ERROR me@example.com 'true'
local cmd = Ssh.exec("example.com", "true", {
  user = "me",
  extra = { "-vv", "-o", "LogLevel=ERROR" },
})
```
