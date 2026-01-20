# archive

Thin wrapper around `tar` for creating, extracting, and listing archives.

> This module constructs `ward.process.cmd(...)` invocations; it does not parse output.
> consumers can use `wardlib.tools.out` (or their own parsing) on the `:output()`
> result.

## Import

```lua
local Archive = require("wardlib.app.archive").Archive
```

## Privilege escalation

This module does not implement `sudo`/`doas` options. If you need elevated
privileges (e.g. extracting into a root-owned directory), use `wardlib.tools.with`
middleware.

```lua
local w = require("wardlib.tools.with")
local Archive = require("wardlib.app.archive").Archive

w.with(w.middleware.sudo(), Archive.extract("/tmp/app.tar.gz", { to = "/srv/app" })):run()
```

## API

### `Archive.bin`

Executable name or path used for `tar`.

### `Archive.create(archive_path, inputs, opts)`

Builds: `tar -c <common opts...> -f <archive_path> <inputs...>`

- `archive_path` (string): output archive path.
- `inputs` (`string[]`): paths to include (must be non-empty).
- `opts` (`ArchiveCommonOpts|nil`): modeled options.

### `Archive.extract(archive_path, opts)`

Builds: `tar -x <common opts...> -f <archive_path> [--strip-components=N] [-C <to>]`

- `archive_path` (string): archive path.
- `opts` (`ArchiveExtractOpts|nil`): modeled options.

### `Archive.list(archive_path, opts)`

Builds: `tar -t <common opts...> -f <archive_path>`

- `archive_path` (string): archive path.
- `opts` (`ArchiveCommonOpts|nil`): modeled options.

## Options

### `ArchiveCommonOpts`

- `dir: string|nil` — For `create` only: `-C <dir>` before input paths.
- `verbose: boolean|nil` — `-v`.
- `compression: "gz"|"xz"|"zstd"|nil` — Compression selector:
  - `"gz"` → `-z`
  - `"xz"` → `-J`
  - `"zstd"` → `--zstd`
- `extra: string[]|nil` — Pass-through flags appended after modeled options.

### `ArchiveExtractOpts`

Extends `ArchiveCommonOpts` with:

- `to: string|nil` — Destination directory: `-C <to>`.
- `strip_components: integer|nil` — `--strip-components=<n>`.

### `extra` ordering

`extra` is appended after modeled options:

- for `create`: before `-f <archive_path>` and before input paths
- for `extract`: before `-f <archive_path>`
- for `list`: before `-f <archive_path>`

## Examples

### Create tar.gz from a project directory

```lua
local Archive = require("wardlib.app.archive").Archive

-- tar -c -z -C /home/me/project -f /tmp/project.tar.gz .
local cmd = Archive.create("/tmp/project.tar.gz", { "." }, {
  dir = "/home/me/project",
  compression = "gz",
})
```

### Create an xz archive of selected paths (verbose)

```lua
local Archive = require("wardlib.app.archive").Archive

-- tar -c -J -v -C /home/me -f /tmp/stuff.tar.xz docs photos
local cmd = Archive.create("/tmp/stuff.tar.xz", { "docs", "photos" }, {
  dir = "/home/me",
  compression = "xz",
  verbose = true,
})
```

### Extract into a destination directory

```lua
local Archive = require("wardlib.app.archive").Archive

-- tar -x -f /tmp/project.tar.gz -C /srv/app
local cmd = Archive.extract("/tmp/project.tar.gz", {
  to = "/srv/app",
})
```

### Extract while stripping top-level directory

```lua
local Archive = require("wardlib.app.archive").Archive

-- tar -x -f /tmp/project.tar.gz --strip-components=1 -C /srv/app
local cmd = Archive.extract("/tmp/project.tar.gz", {
  strip_components = 1,
  to = "/srv/app",
})
```

### List archive contents and parse as lines

```lua
local Archive = require("wardlib.app.archive").Archive
local out = require("wardlib.tools.out")

-- tar -t -v -f /tmp/project.tar.gz
local res = Archive.list("/tmp/project.tar.gz", { verbose = true }):output()
local lines = out.res(res):ok():lines()
```

### Pass-through extra tar flags

```lua
local Archive = require("wardlib.app.archive").Archive

-- tar -c -z -C /home/me/project --exclude=.git --exclude=target -f /tmp/src.tar.gz .
local cmd = Archive.create("/tmp/src.tar.gz", { "." }, {
  dir = "/home/me/project",
  compression = "gz",
  extra = { "--exclude=.git", "--exclude=target" },
})
```
