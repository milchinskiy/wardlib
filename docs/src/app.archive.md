# archive

## Create tar.gz from a project directory

```lua
local Archive = require("app.archive").Archive

-- Equivalent to: tar -c -z -C /home/me/project -f /tmp/project.tar.gz .
local cmd = Archive.create("/tmp/project.tar.gz", { "." }, {
  dir = "/home/me/project",
  compression = "gz",
})
```

## Create an xz archive of selected paths (verbose)

```lua
local Archive = require("app.archive").Archive

-- Equivalent to: tar -c -J -v -C /home/me -f /tmp/stuff.tar.xz docs photos
local cmd = Archive.create("/tmp/stuff.tar.xz", { "docs", "photos" }, {
  dir = "/home/me",
  compression = "xz",
  verbose = true,
})
```

## Extract into a destination directory

```lua
local Archive = require("app.archive").Archive

-- Equivalent to: tar -x -f /tmp/project.tar.gz -C /srv/app
local cmd = Archive.extract("/tmp/project.tar.gz", {
  to = "/srv/app",
})
```

## Extract while stripping top-level directory

```lua
local Archive = require("app.archive").Archive

-- Equivalent to: tar -x -f /tmp/project.tar.gz --strip-components=1 -C /srv/app
local cmd = Archive.extract("/tmp/project.tar.gz", {
  strip_components = 1,
  to = "/srv/app",
})
```

## List archive contents

```lua
local Archive = require("app.archive").Archive

-- Equivalent to: tar -t -v -f /tmp/project.tar.gz
local cmd = Archive.list("/tmp/project.tar.gz", {
  verbose = true,
})
```

## Use zstd compression (if your tar supports it)

```lua
local Archive = require("app.archive").Archive

-- Equivalent to: tar -c --zstd -C /home/me/project -f /tmp/project.tar.zst .
local cmd = Archive.create("/tmp/project.tar.zst", { "." }, {
  dir = "/home/me/project",
  compression = "zstd",
})
```

## Pass-through extra tar flags

`extra` is appended after modeled options (before `-f` for create/list and before paths)

```lua
local Archive = require("app.archive").Archive

-- Example: exclude VCS and build output
-- Equivalent to: tar -c -z -C /home/me/project --exclude=.git --exclude=target -f /tmp/src.tar.gz .
local cmd = Archive.create("/tmp/src.tar.gz", { "." }, {
  dir = "/home/me/project",
  compression = "gz",
  extra = { "--exclude=.git", "--exclude=target" },
})
```
