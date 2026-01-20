# wget

`wget` is a command-line file downloader.

> This module constructs `ward.process.cmd(...)` invocations; it does not parse output.
> consumers can use `wardlib.tools.out` (or their own parsing) on the `:output()`
> result.

Notes:

- `Wget.fetch(nil, { input_file = "urls.txt" })` is the idiomatic way to build
a command that reads URLs from an input file.
- GNU wget option surface is large; this wrapper models a practical subset and
provides `extra` for the rest.

## Import

```lua
local Wget = require("wardlib.app.wget").Wget
```

## API

### `Wget.fetch(urls, opts)`

Builds: `wget <opts...> [urls...]`

- If `urls` is `nil`, runs wget with only the configured options (useful with `-i`).
- If `urls` is a string array, all URLs are appended.

### `Wget.download(url, out, opts)`

Convenience for a single URL.

- If `out` is provided, sets `opts.output_document` (`-O <out>`).

### `Wget.mirror_site(url, dir, opts)`

Convenience for mirroring.

- Always sets `opts.mirror = true` (`-m`).
- If `dir` is provided, sets `opts.directory_prefix` (`-P <dir>`).

## Options (`WgetOpts`)

Verbosity:

- `quiet: boolean?` — `-q`
- `verbose: boolean?` — `-v`
- `no_verbose: boolean?` — `-nv`

Download behavior:

- `continue: boolean?` — `-c`
- `timestamping: boolean?` — `-N`
- `no_clobber: boolean?` — `-nc`
- `spider: boolean?` — `--spider`

Output / input:

- `output_document: string?` — `-O <file>`
- `directory_prefix: string?` — `-P <dir>`
- `input_file: string?` — `-i <file>`

HTTP:

- `user_agent: string?` — `-U <ua>`
- `header: string|string[]?` — `--header=<h>` (repeatable)
- `method: string?` — `--method=<method>`
- `post_data: string?` — `--post-data=<data>`
- `post_file: string?` — `--post-file=<file>`
- `body_data: string?` — `--body-data=<data>`
- `body_file: string?` — `--body-file=<file>`
- `no_check_certificate: boolean?` — `--no-check-certificate`

Networking:

- `inet4_only: boolean?` — `-4`
- `inet6_only: boolean?` — `-6`
- `timeout: number?` — `--timeout=<sec>`
- `wait: number?` — `--wait=<sec>`
- `tries: number?` — `--tries=<n>`

Recursion / mirroring:

- `recursive: boolean?` — `-r`
- `level: number?` — `-l <n>`
- `no_parent: boolean?` — `-np`
- `mirror: boolean?` — `-m`
- `page_requisites: boolean?` — `-p`
- `convert_links: boolean?` — `-k`
- `adjust_extension: boolean?` — `-E`

Escape hatch:

- `extra: string[]?` — extra argv appended after modeled options

## Examples

### Download a file

```lua
local Wget = require("wardlib.app.wget").Wget

-- wget -O out.bin https://example.com/file
local cmd = Wget.download("https://example.com/file", "out.bin")
```

### Download multiple URLs into a directory

```lua
local Wget = require("wardlib.app.wget").Wget

-- wget -P /tmp/downloads https://a https://b
local cmd = Wget.fetch({
  "https://example.com/a",
  "https://example.com/b",
}, { directory_prefix = "/tmp/downloads" })
```

### Add custom headers and timeouts

```lua
local Wget = require("wardlib.app.wget").Wget

-- wget -q --timeout=10 --header="Accept: */*" https://example.com
local cmd = Wget.fetch("https://example.com", {
  quiet = true,
  timeout = 10,
  header = "Accept: */*",
})
```

### Read URLs from a file

```lua
local Wget = require("wardlib.app.wget").Wget

-- wget -i urls.txt -P out
local cmd = Wget.fetch(nil, { input_file = "urls.txt", directory_prefix = "out" })
```

### Mirror a website into a directory

```lua
local Wget = require("wardlib.app.wget").Wget

-- wget -m -P /tmp/site https://example.com
local cmd = Wget.mirror_site("https://example.com", "/tmp/site")
```
