# config

`wardlib.tools.config` is a small, format-aware configuration IO layer.

Ward already provides codecs under `ward.convert.*` (JSON, YAML, TOML, INI).
This tool focuses on common scripting workflows around those codecs:

- infer format from file extension (or override explicitly)
- read/write config as a Lua table
- patch config in-place
- merge tables (shallow or deep) via Ward core helpers

## Module

```lua
local config = require("wardlib.tools.config")
```

## Supported formats

The format is inferred by file extension:

- `.json` -> `json`
- `.yaml` / `.yml` -> `yaml`
- `.toml` -> `toml`
- `.ini` -> `ini`

You can also override the format via `opts.format` in `read`, `write`, and `patch`.

## Examples

### Read / write

```lua
local config = require("wardlib.tools.config")

config.write("app.json", { enabled = true }, { pretty = true, mkdir = true })
local doc = config.read("app.json")
assert(doc.enabled == true)
```

### Patch in-place

```lua
local config = require("wardlib.tools.config")

config.patch("app.json", function(doc)
 doc.port = 8080
 -- return nil to mutate in place
end)
```

### Merge

```lua
local config = require("wardlib.tools.config")

local base = { a = { x = 1, y = 1 } }
local overlay = { a = { y = 2 } }

local out = config.merge(base, overlay, { mode = "deep" })
assert(out.a.x == 1)
assert(out.a.y == 2)
```

## API

### `config.infer_format(path) -> string|nil`

Returns `"json"`, `"yaml"`, `"toml"`, `"ini"`, or `nil` if the extension is not recognized.

### `config.read(path, opts?) -> any`

Reads `path` as text and decodes it using the inferred (or overridden) format.

Options:

- `format` (string|nil) - override inferred format

Errors if the file does not exist.

### `config.write(path, value, opts?) -> boolean`

Encodes `value` and writes it to `path`.

Returns:

- `true` when it wrote the file
- `false` when `write_if_changed=true` and the file already contained identical content

Options:

- `format` (string|nil) - override inferred format
- `mkdir` (boolean, default `false`) - create parent directory
- `write_if_changed` (boolean, default `false`) - skip writing when content is identical
- `eof_newline` (boolean, default `true`) - ensure output ends with `\n`

JSON-only options:

- `pretty` (boolean, default `false`)
- `indent` (integer|nil) - spaces per indent level

### `config.patch(path, fn, opts?) -> any`

Reads config from `path`, calls `fn(doc)`, and writes the result back.

Patch function semantics:

- if `fn(doc)` returns a non-nil value, it is treated as the new document
- if it returns `nil`, the existing `doc` is assumed mutated in-place

Options:

- all `write()` options
- `allow_missing` (boolean, default `true`) - if file is missing, start from
`opts.default` or `{}`
- `default` (any|nil) - initial document when file is missing

### `config.merge(base, overlay, opts?) -> table`

Merges two tables using Ward core helpers:

- `mode = "deep"` (default) uses `ward.helpers.table.deep_merge`
- `mode = "shallow"` uses `ward.helpers.table.merge`
