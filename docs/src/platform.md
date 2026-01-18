# tools.platform

`tools.platform` provides a small, cross-platform inspection API for scripts.

It delegates to Ward core `ward.host.platform` and adds a few conveniences that
are commonly needed in wardlib scripts:

- `is_ci()` CI detection via common environment variables
- `home()` best-effort home directory resolution
- `tmpdir()` best-effort temporary directory resolution
- `os_release()` parsing for Linux distributions (best-effort)

## Usage

```lua
local platform = require("wardlib.tools.platform")

local info = platform.info()
print(info.os, info.arch, info.is_ci)

if platform.is_macos() then
  -- macOS-specific logic
end
```

## API

### `platform.info() -> table`

Returns the Ward core `ward.host.platform.info()` table, extended with:

- `is_ci` (boolean)
- `home` (string|nil)
- `tmpdir` (string|nil)

### `platform.is_ci() -> boolean`

Returns true if the environment looks like CI.

### `platform.home() -> string|nil`

Home directory detection.

Resolution order:

1) `HOME`
2) `USERPROFILE`
3) `HOMEDRIVE` + `HOMEPATH`

### `platform.tmpdir() -> string|nil`

Temporary directory detection.

Resolution order:

1) `TMPDIR`
2) `TEMP`
3) `TMP`
4) `/tmp` on Unix targets

### `platform.os_release(opts?) -> table|nil`

Linux distribution metadata.

- Reads `/etc/os-release` (or `/usr/lib/os-release` fallback) and returns a parsed key/value table.
- On non-Linux targets, returns `nil`.

Options:

- `path` (string): override file path

### `platform.parse_os_release(text) -> table`

Parses an `os-release` formatted string into a table with lower-case keys (for example `ID` becomes `id`).
