# xz

`xz` compresses and decompresses files using LZMA2.

> The wrapper constructs a `ward.process.cmd(...)` invocation; it does
> not parse output.

## Compress with level and threads

```lua
local Xz = require("app.xz").Xz

-- Equivalent to: xz -e -6 -T 0 -- data.json
local cmd = Xz.compress("data.json", { level = 6, extreme = true, threads = 0 })
```

## Decompress

```lua
local Xz = require("app.xz").Xz

-- Equivalent to: xz -d -k -- data.json.xz
local cmd = Xz.decompress("data.json.xz", { keep = true })
```

## Pass-through extra xz flags

```lua
local Xz = require("app.xz").Xz

-- Equivalent to: xz --check=crc64 -- file
local cmd = Xz.run("file", { extra = { "--check=crc64" } })
```
