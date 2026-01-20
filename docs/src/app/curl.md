# curl

`curl` is a command-line tool for transferring data (HTTP, HTTPS, etc.).

> This module constructs `ward.process.cmd(...)` invocations; it does not parse output.
> consumers can use `wardlib.tools.out` (or their own parsing) on the `:output()`
> result.

## Import

```lua
local Curl = require("wardlib.app.curl").Curl
```

## API

### `Curl.request(urls, opts)`

Builds: `curl <opts...> [urls...]`

- `urls`: `string|string[]|nil`
  - If `nil`, `curl` runs with only the configured options.

### `Curl.get(url, opts)`

Convenience for `Curl.request(url, opts)`.

### `Curl.head(url, opts)`

Convenience for `Curl.request(url, { head = true, ... })`.

### `Curl.download(url, out, opts)`

Convenience for downloading a URL.

- If `out` is provided, uses `-o <out>`.
- Otherwise uses `-O` (remote name).

### `Curl.post(url, data, opts)`

Convenience for POSTing a request body.

- If `opts.request` is not set, defaults to `POST`.
- If `data` is provided, sets `-d <data>`.

All functions return a `ward.process.cmd(...)` object.

## Options (`CurlOpts`)

Common fields:

- Verbosity / error handling: `silent` (`-s`), `show_error` (`-S`),
`verbose` (`-v`), `fail` (`--fail`)
- Redirects / method: `location` (`-L`), `head` (`-I`), `request` (`-X <method>`)
- Request body: `data` (`-d <data>`), `data_raw` (`--data-raw <data>`),
`form` (`-F <name=content>`, repeatable)
- Headers / identity: `user_agent` (`-A <ua>`), `header` (`-H <header>`, repeatable)
- Cookies: `cookie` (`-b <cookie>`), `cookie_jar` (`-c <file>`)
- Output: `output` (`-o <file>`), `remote_name` (`-O`), `remote_header_name` (`-J`)
- TLS: `insecure` (`-k`), `cacert` (`--cacert <file>`),
`cert` (`--cert <cert[:passwd]>`), `key` (`--key <key>`)
- Timeouts / retries: `connect_timeout` (`--connect-timeout <sec>`),
`max_time` (`--max-time <sec>`), `retry` (`--retry <n>`)
- Misc: `compressed` (`--compressed`), `ipv4` (`-4`), `ipv6` (`-6`),
`http1_1` (`--http1.1`), `http2` (`--http2`)
- Formatting: `write_out` (`-w <format>`)
- Escape hatch: `extra` (appended after modeled options)

## Examples

### GET with redirects and headers

```lua
local Curl = require("wardlib.app.curl").Curl

-- curl -s -S -L -H 'Accept: */*' https://example.com
local cmd = Curl.get("https://example.com", {
  silent = true,
  show_error = true,
  location = true,
  header = "Accept: */*",
})
```

### Download to a file

```lua
local Curl = require("wardlib.app.curl").Curl

-- curl -L -o out.bin https://example.com/file
local cmd = Curl.download("https://example.com/file", "out.bin")
```

### POST form-encoded data

```lua
local Curl = require("wardlib.app.curl").Curl

-- curl -X POST -d 'a=1&b=2' https://example.com/api
local cmd = Curl.post("https://example.com/api", "a=1&b=2")
```

### Capture output and parse JSON

```lua
local Curl = require("wardlib.app.curl").Curl
local out = require("wardlib.tools.out")

local res = Curl.get("https://api.github.com/repos/neovim/neovim", {
  silent = true,
  show_error = true,
  fail = true,
  header = "Accept: application/vnd.github+json",
}):output()

local obj = out.res(res):label("curl github api"):json()
-- obj.full_name, obj.stargazers_count, ...
```
