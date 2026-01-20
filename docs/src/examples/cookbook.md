# Cookbook

This page collects pragmatic, end-to-end examples of Ward scripts built from
Ward core modules and wardlib wrappers.

The examples are intentionally "real life": they show complete workflows
(execute commands, parse output, apply changes) rather than isolated API calls.

## Git: detect repo root and show short status

```lua
local Git = require("wardlib.app.git").Git
local out = require("wardlib.tools.out")

local dir = "/home/me/project"

-- Repo root as a string.
local root = out.cmd(Git.root({ dir = dir }))
  :label("git root")
  :trim()
  :line()

-- Short status lines.
local status = out.cmd(Git.status({ dir = dir, short = true, branch = true }))
  :label("git status")
  :lines()

print("root:", root)
for _, line in ipairs(status) do
  print(line)
end
```

## Git: clone if missing

```lua
local fs = require("ward.fs")
local Git = require("wardlib.app.git").Git

local url = "https://example.com/repo.git"
local dest = "/home/me/src/repo"

if not fs.is_exists(dest) then
  Git.clone(url, dest, { depth = 1 }):run()
end
```

## systemd: ensure a unit is enabled and active

This pattern is common for both system services and `--user` services.

```lua
local Systemd = require("wardlib.app.systemd").Systemd
local out = require("wardlib.tools.out")

local unit = "nginx.service"

-- Enable and start.
Systemd.enable(unit, { now = true }):run()

-- Parse state (allow non-zero exit codes; state is still printed).
local state = out.cmd(Systemd.is_active(unit))
  :label("systemctl is-active")
  :allow_fail()
  :trim()
  :line()

if state ~= "active" then
  error(unit .. " is not active: " .. state)
end
```

## systemd: fetch recent logs as JSON Lines

```lua
local Systemd = require("wardlib.app.systemd").Systemd
local out = require("wardlib.tools.out")

local unit = "nginx.service"

local entries = out.cmd(Systemd.journal(unit, { output = "json", lines = 50 }))
  :label("journalctl -o json")
  :json_lines()

for _, e in ipairs(entries) do
  -- Common journal fields include MESSAGE, PRIORITY, _PID, _SYSTEMD_UNIT.
  if e.MESSAGE then
    print(e.MESSAGE)
  end
end
```

## Networking: list IPv4 addresses with `ip -j`

```lua
local Ip = require("wardlib.app.ip").Ip
local out = require("wardlib.tools.out")

local ifaces = out.cmd(Ip.raw({ "addr", "show" }, { json = true }))
  :label("ip -j addr show")
  :json()

local v4 = {}
for _, iface in ipairs(ifaces) do
  local ai = iface.addr_info or {}
  for _, a in ipairs(ai) do
    if a.family == "inet" and a.local then
      v4[#v4 + 1] = { ifname = iface.ifname, addr = a.local }
    end
  end
end

for _, x in ipairs(v4) do
  print(x.ifname .. ":" .. x.addr)
end
```

## Download, verify, and extract

This is a typical "fetch a release artifact" workflow.

```lua
local fs = require("ward.fs")
local out = require("wardlib.tools.out")
local Curl = require("wardlib.app.curl").Curl
local Sha256sum = require("wardlib.app.sha256sum").Sha256sum
local Unzip = require("wardlib.app.unzip").Unzip

local url = "https://example.com/releases/tool.zip"
local zip = "/tmp/tool.zip"
local expected_sha = "0123456789abcdef..."
local dest = "/opt/tool"

-- Download.
Curl.download(url, zip):run()

-- Verify sha256 (sha256sum prints: <hex>  <path>).
local sha = out.cmd(Sha256sum.sum(zip))
  :label("sha256sum")
  :trim()
  :match("^(%x+)")

if sha ~= expected_sha then
  error("checksum mismatch: expected " .. expected_sha .. ", got " .. sha)
end

-- Extract.
fs.mkdir(dest, { recursive = true })
Unzip.extract(zip, { overwrite = true, to = dest }):run()
```

## Cross-distro package install (pattern)

Use `wardlib.tools.platform` and the distro's package manager wrapper.

```lua
local platform = require("wardlib.tools.platform")
local AptGet = require("wardlib.app.aptget").AptGet
local Pacman = require("wardlib.app.pacman").Pacman
local Dnf = require("wardlib.app.dnf").Dnf

local pkgs = { "git", "curl" }

local osr = platform.os_release() or {}
local id = osr.id

if id == "debian" or id == "ubuntu" then
  AptGet.update({ sudo = true, assume_yes = true }):run()
  AptGet.install(pkgs, { sudo = true, assume_yes = true }):run()
elseif id == "arch" then
  Pacman.sync({ sudo = true }):run()
  Pacman.install(pkgs, { sudo = true, needed = true }):run()
elseif id == "fedora" then
  Dnf.install(pkgs, { sudo = true, assume_yes = true }):run()
else
  error("unsupported distro: " .. tostring(id))
end
```

## Dotfiles: apply a minimal preset

```lua
local dotfiles = require("wardlib.tools.dotfiles")

local def = dotfiles.define("Minimal dotfiles", {
  description = "Small starter config",
  steps = {
    dotfiles.content(".config/myapp/config.toml", [[
enabled = true
    ]]),

    dotfiles.link(".config/fish", "~/.dotfiles/fish", { recursive = true }),
  },
})

def:apply("/home/me", { force = true })
```
