# tools.ensure

`tools.ensure` provides **fail-fast contract checks** for Ward scripts.

This is intentionally not a portability layer.

- It does not negotiate distro "flavors", package managers, or versions.
- It does not attempt to auto-install missing tools.
- It does not claim idempotent "ensure state" semantics.

It simply makes script assumptions explicit and actionable.

## Example

```lua
local ensure = require("wardlib.tools.ensure")

ensure.os("linux")
ensure.bins({ "git", "tar", "ssh" })

local token = ensure.env("TOKEN")

-- If the script needs privileged operations:
ensure.root()
```

## API

### `ensure.bin(name_or_path, opts?) -> string`

Ensure a binary exists (either an explicit path, or a name in PATH).
Returns the resolved path when possible.

### `ensure.bins(bins, opts?) -> table`

Ensure a set of binaries exist. Returns `{ [name] = resolved_path }`.

### `ensure.env(keys, opts?) -> string | table`

Ensure environment variable(s) exist.

- If passed a string, returns its value.
- If passed `string[]`, returns a map.

Options:

- `allow_empty` (bool, default `false`) - treat empty string as missing.

### `ensure.root(opts?) -> true`

Ensure the script is running as root (Unix).

### `ensure.os(allowed, opts?) -> string`

Ensure current OS is allowed. Supported allowed values:

- `"linux"`
- `"darwin"`
- `"freebsd"`
- `"openbsd"`
- `"netbsd"`
- `"windows"`
- `"unix"`
