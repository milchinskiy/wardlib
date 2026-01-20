# rsync

`rsync` synchronizes files and directories efficiently (local or remote). It is commonly
used for deployment, backup, and mirroring.

> This module constructs `ward.process.cmd(...)` invocations; it does not parse output.
> consumers can use `wardlib.tools.out` (or their own parsing) on the `:output()`
> result.

## Import

```lua
local Rsync = require("wardlib.app.rsync").Rsync
```

## API

### `Rsync.bin`

Executable name or path (default: `"rsync"`).

### `Rsync.sync(src, dest, opts)`

Builds: `rsync <opts...> <src...> <dest>`

- `src`: `string|string[]` (one or many sources)
- `dest`: `string` (destination directory or remote target)

## Options

### `RsyncOpts`

- `archive: boolean?` → `-a`
- `compress: boolean?` → `-z`
- `verbose: boolean?` → `-v`
- `progress: boolean?` → `--progress`
- `delete: boolean?` → `--delete`
- `dry_run: boolean?` → `--dry-run`
- `checksum: boolean?` → `--checksum`
- `partial: boolean?` → `--partial`
- `excludes: string[]?` → `--exclude <pattern>` (repeatable)
- `include: string[]?` → `--include <pattern>` (repeatable)
- `rsh: string?` → `-e <rsh>` (e.g. `"ssh -p 2222 -i ~/.ssh/id_ed25519"`)
- `extra: string[]?` → extra argv appended before src/dest

## Examples

### Local directory sync (archive + delete)

```lua
local Rsync = require("wardlib.app.rsync").Rsync

-- rsync -a --delete ./src/ ./dst/
local cmd = Rsync.sync("./src/", "./dst/", {
  archive = true,
  delete = true,
})
cmd:run()
```

### Remote sync over SSH with excludes

```lua
local Rsync = require("wardlib.app.rsync").Rsync

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
cmd:run()
```

### Multiple sources into one destination

```lua
local Rsync = require("wardlib.app.rsync").Rsync

-- rsync -a a/ b/ ./dst/
Rsync.sync({ "a/", "b/" }, "./dst/", { archive = true }):run()
```

### Dry run with progress

```lua
local Rsync = require("wardlib.app.rsync").Rsync

-- rsync -a --dry-run --progress ./src/ host:/dst/
Rsync.sync("./src/", "host:/dst/", {
  archive = true,
  dry_run = true,
  progress = true,
}):run()
```

### Include / exclude patterns

```lua
local Rsync = require("wardlib.app.rsync").Rsync

-- rsync -a --include "*.lua" --exclude "*" ./src/ ./dst/
Rsync.sync("./src/", "./dst/", {
  archive = true,
  include = { "*.lua" },
  excludes = { "*" },
}):run()
```
