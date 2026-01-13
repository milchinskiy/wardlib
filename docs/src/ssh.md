# SSH

## Interactive SSH session (with identity + port)

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

## Run a remote command (array form)

```lua
local Ssh = require("wardlib.app.ssh").Ssh

-- Equivalent to: ssh me@example.com "systemctl" "--user" "status" "pipewire.service"
local cmd = Ssh.exec("example.com", { "systemctl", "--user", "status", "pipewire.service" }, {
  user = "me",
})
```

## Hardened non-interactive connection (BatchMode + host key policy)

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

## Copy local -> remote (scp)

```lua
local Ssh = require("wardlib.app.ssh").Ssh

-- Equivalent to: scp -P 2200 -C ./build.tar.gz me@example.com:/tmp/build.tar.gz
local cmd = Ssh.copy_to("example.com", "./build.tar.gz", "/tmp/build.tar.gz", {
  user = "me",
  port = 2200,
  compress = true,
})
```

## Copy remote -> local (scp)

```lua
local Ssh = require("wardlib.app.ssh").Ssh

-- Equivalent to: scp -P 2200 me@example.com:/var/log/syslog ./syslog
local cmd = Ssh.copy_from("example.com", "/var/log/syslog", "./syslog", {
  user = "me",
  port = 2200,
})
```

## Use `ssh.scp` directly (recursive directory copy)

```lua
local Ssh = require("wardlib.app.ssh").Ssh

-- Equivalent to: scp -r ./dist me@example.com:/srv/app/dist
local cmd = Ssh.scp("./dist", "me@example.com:/srv/app/dist", {
  recursive = true,
})
```

## Advanced flags via `extra`

```lua
local Ssh = require("wardlib.app.ssh").Ssh

-- Equivalent to: ssh -vv -o LogLevel=ERROR me@example.com 'true'
local cmd = Ssh.exec("example.com", "true", {
  user = "me",
  extra = { "-vv", "-o", "LogLevel=ERROR" },
})
```
