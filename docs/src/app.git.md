# Git

## Status in a specific repo directory

```lua
local Git = require("wardlib.app.git").Git

-- Equivalent to: git -C /home/me/project status -s -b
local cmd = Git.status({
  dir = "/home/me/project",
  short = true,
  branch = true,
})

-- cmd:output()
```

## Root of repository

```lua
local Git = require("app.git").Git

-- Equivalent to: git -C /home/me/project rev-parse --show-toplevel
local cmd = Git.root({ dir = "/home/me/project" })

-- cmd:output()
```

## Check "is this a git work tree?"

```lua
local Git = require("app.git").Git

-- Equivalent to: git -C /home/me/project rev-parse --is-inside-work-tree
local cmd = Git.is_repo({ dir = "/home/me/project" })

-- Conventionally, exit code 0 means "yes".
```

## Clone (shallow + branch)

```lua
local Git = require("app.git").Git

-- Equivalent to: git clone --depth 1 --branch main https://example.com/repo.git repo
local cmd = Git.clone("https://example.com/repo.git", "repo", {
  depth = 1,
  branch = "main",
})
```

## Clone (recursive)

```lua
local Git = require("app.git").Git

-- Equivalent to: git clone --recursive https://example.com/repo.git
local cmd = Git.clone("https://example.com/repo.git", nil, {
  recursive = true,
})
```

## Push with upstream

```lua
local Git = require("app.git").Git

-- Equivalent to: git -C /home/me/project push -u origin main
local cmd = Git.push("origin", "main", {
  dir = "/home/me/project",
  upstream = true,
})
```

## Pass-through extra arguments

`extra` is a direct append to the subcommand argv. Use it for flags you
don't want to model yet.

```lua
local Git = require("app.git").Git

-- Equivalent to: git -C /home/me/project status -s --ignored=matching
local cmd = Git.status({
  dir = "/home/me/project",
  short = true,
  extra = { "--ignored=matching" },
})

-- Equivalent to: git push --force-with-lease origin main
local cmd2 = Git.push("origin", "main", {
  dir = "/home/me/project",
  extra = { "--force-with-lease" },
})
```

## Use an explicit git binary

```lua
local Git = require("app.git").Git
Git.bin = "/usr/bin/git"  -- or another path
local cmd = Git.status({ dir = "/home/me/project", short = true })
```
