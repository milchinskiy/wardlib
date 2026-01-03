# sed

`sed` is a stream editor for filtering and transforming text.

The wrapper constructs a `ward.process.cmd(...)` invocation; it does not parse output.

## Apply a script to stdin

```lua
local Sed = require("app.sed").Sed

-- Equivalent to: sed -e 's/foo/bar/g'
local cmd = Sed.script("s/foo/bar/g")
```

## Apply a script to files

```lua
local Sed = require("app.sed").Sed

-- Equivalent to: sed -E -e 's/foo/bar/g' a.txt b.txt
local cmd = Sed.replace("foo", "bar", { "a.txt", "b.txt" }, { extended = true })
```

## In-place edit

```lua
local Sed = require("app.sed").Sed

-- Equivalent to: sed -i.bak -e 's/hello/hi/g' file.txt
local cmd = Sed.inplace_replace("hello", "hi", "file.txt", ".bak")
```

## Multiple expressions

```lua
local Sed = require("app.sed").Sed

-- Equivalent to: sed -e 's/a/b/g' -e 's/c/d/g' file.txt
local cmd = Sed.run("file.txt", {
  expression = { "s/a/b/g", "s/c/d/g" },
})
```
