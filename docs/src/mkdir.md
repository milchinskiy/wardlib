# mkdir

`mkdir` creates directories.

> The wrapper constructs a `ward.process.cmd(...)` invocation; it does
> not parse output.

## Create a directory tree

```lua
local Mkdir = require("wardlib.app.mkdir").Mkdir

-- Equivalent to: mkdir -p -- a/b/c
local cmd = Mkdir.make("a/b/c", { parents = true })
```

## Create multiple directories with a mode

```lua
local Mkdir = require("wardlib.app.mkdir").Mkdir

-- Equivalent to: mkdir -p -m 0755 -- bin lib
local cmd = Mkdir.make({ "bin", "lib" }, { parents = true, mode = "0755" })
```
