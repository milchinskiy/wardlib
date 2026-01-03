# wget

`wget` is a command-line file downloader.

The wrapper constructs a `ward.process.cmd(...)` invocation; it does not parse output.

## Download a file

```lua
local Wget = require("app.wget").Wget

-- Equivalent to: wget -O out.bin https://example.com/file
local cmd = Wget.download("https://example.com/file", "out.bin")
```

## Add custom headers and timeouts

```lua
local Wget = require("app.wget").Wget

-- Equivalent to:
--   wget -q --timeout=10 --header="Accept: */*" https://example.com
local cmd = Wget.fetch("https://example.com", {
  quiet = true,
  timeout = 10,
  header = "Accept: */*",
})
```

## Mirror a website into a directory

```lua
local Wget = require("app.wget").Wget

-- Equivalent to: wget -m -P /tmp/site https://example.com
local cmd = Wget.mirror_site("https://example.com", "/tmp/site")
```
