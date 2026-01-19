# gzip

`gzip` compresses and decompresses files.

> The wrapper constructs a `ward.process.cmd(...)` invocation; it does
> not parse output.

## Compress a file (keep original)

```lua
local Gzip = require("wardlib.app.gzip").Gzip

-- Equivalent to: gzip -k -9 -- data.json
local cmd = Gzip.compress("data.json", { keep = true, level = 9 })
```

## Decompress a file

```lua
local Gzip = require("wardlib.app.gzip").Gzip

-- Equivalent to: gzip -d -f -- data.json.gz
local cmd = Gzip.decompress("data.json.gz", { force = true })
```

## Stream to stdout

```lua
local Gzip = require("wardlib.app.gzip").Gzip

-- Equivalent to: gzip -c -- data.json
local cmd = Gzip.run("data.json", { stdout = true })
```

## Pass-through extra gzip flags

```lua
local Gzip = require("wardlib.app.gzip").Gzip

-- Equivalent to: gzip --rsyncable -- file
local cmd = Gzip.run("file", { extra = { "--rsyncable" } })
```
