# curl

`curl` is a command-line tool for transferring data (HTTP, HTTPS, etc.).

The wrapper constructs a `ward.process.cmd(...)` invocation; it does not parse output.

## GET with redirects and headers

```lua
local Curl = require("app.curl").Curl

-- Equivalent to:
--   curl -s -S -L -H "Accept: */*" https://example.com
local cmd = Curl.get("https://example.com", {
  silent = true,
  show_error = true,
  location = true,
  header = "Accept: */*",
})
```

## Download to a file

```lua
local Curl = require("app.curl").Curl

-- Equivalent to: curl -L -o out.bin https://example.com/file
local cmd = Curl.download("https://example.com/file", "out.bin")
```

## POST form-encoded data

```lua
local Curl = require("app.curl").Curl

-- Equivalent to:
--   curl -X POST -d "a=1&b=2" https://example.com/api
local cmd = Curl.post("https://example.com/api", "a=1&b=2")
```
