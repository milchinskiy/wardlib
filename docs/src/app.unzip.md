# unzip

`unzip` extracts and inspects zip archives.

> The wrapper constructs a `ward.process.cmd(...)` invocation; it does not
> parse output.

Note: Info-ZIP `unzip` does not support `--` as end-of-options. For safety, this
wrapper rejects zip paths (and optional file lists) that start with `-`.

## Extract into a destination directory

```lua
local Unzip = require("app.unzip").Unzip

-- Equivalent to: unzip -o a.zip -d out
local cmd = Unzip.extract("a.zip", { overwrite = true, to = "out" })
```

## Extract only specific files and exclude patterns

```lua
local Unzip = require("app.unzip").Unzip

-- Equivalent to: unzip a.zip x y -x "*.tmp" "*.bak" -d out
local cmd = Unzip.extract("a.zip", {
  files = { "x", "y" },
  exclude = { "*.tmp", "*.bak" },
  to = "out",
})
```

## List contents

```lua
local Unzip = require("app.unzip").Unzip

-- Equivalent to: unzip -q -l a.zip
local cmd = Unzip.list("a.zip", { quiet = true })
```
