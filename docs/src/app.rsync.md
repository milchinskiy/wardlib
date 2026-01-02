# rsync

## Local directory sync (archive + delete)

```lua
local Rsync = require("app.rsync").Rsync

-- Equivalent to: rsync -a --delete ./src/ ./dst/
local cmd = Rsync.sync("./src/", "./dst/", {
  archive = true,
  delete = true,
})
```

## Remote sync over SSH with excludes

```lua
local Rsync = require("app.rsync").Rsync

-- Equivalent to:
-- rsync -a -z --delete -e "ssh -p 2222 -i ~/.ssh/id_ed25519" \
--   --exclude .git --exclude target \
--   ./project/ me@host:/srv/project/
local cmd = Rsync.sync("./project/", "me@host:/srv/project/", {
  archive = true,
  compress = true,
  delete = true,
  rsh = "ssh -p 2222 -i ~/.ssh/id_ed25519",
  excludes = { ".git", "target" },
})
```

## Multiple sources into one destination

```lua
local Rsync = require("app.rsync").Rsync

-- Equivalent to: rsync -a a/ b/ ./dst/
local cmd = Rsync.sync({ "a/", "b/" }, "./dst/", { archive = true })
```

## Dry run with progress

```lua
local Rsync = require("app.rsync").Rsync

-- Equivalent to: rsync -a --dry-run --progress ./src/ host:/dst/
local cmd = Rsync.sync("./src/", "host:/dst/", {
  archive = true,
  dry_run = true,
  progress = true,
})
```

## Include / exclude patterns

```lua
local Rsync = require("app.rsync").Rsync

-- Equivalent to:
-- rsync -a --include "*.lua" --exclude "*" ./src/ ./dst/
local cmd = Rsync.sync("./src/", "./dst/", {
  archive = true,
  include = { "*.lua" },
  excludes = { "*" },
})
```
