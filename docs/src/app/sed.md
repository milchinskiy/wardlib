# sed

`sed` is a stream editor for filtering and transforming text.

> This module constructs `ward.process.cmd(...)` invocations; it does not parse output.
> consumers can use `wardlib.tools.out` (or their own parsing) on the `:output()`
> result.

## Import

```lua
local Sed = require("wardlib.app.sed").Sed
```

## Portability notes

- `-E` (extended regex) is supported on both GNU and BSD sed.
- In-place editing (`-i`) differs between implementations. This wrapper models
  `in_place` so it works on GNU sed and is typically accepted on BSD sed as well.
  If you need strict BSD behavior, pass `extra = { "-i", ".bak" }`.

## API

### `Sed.bin`

Executable name or path (default: `"sed"`).

### `Sed.run(inputs, opts)`

Builds: `sed <opts...> [inputs...]`

- If `inputs` is `nil`, sed reads stdin.
- `inputs` accepts `string|string[]|nil`.

### `Sed.script(script, inputs, opts)`

Convenience wrapper around `Sed.run` that adds `-e <script>`.

### `Sed.replace(pattern, repl, inputs, opts)`

Convenience wrapper that adds `-e s/pattern/repl/g`.

> This does not escape `pattern`/`repl`; escape them yourself if needed.

### `Sed.inplace_replace(pattern, repl, inputs, backup_suffix, opts)`

Convenience wrapper that enables in-place editing (via `-i`) and adds the substitution.

- `inputs` must be `string|string[]` (a real file path list).
- `backup_suffix` may be `nil` (GNU-style `-i`) or a string like `.bak`.

## Options

### `SedOpts`

- `extended: boolean?` → `-E`
- `quiet: boolean?` → `-n`
- `in_place: boolean|string?` → `-i` or `-i<suffix>`
- `backup_suffix: string?` → alias for `in_place = "<suffix>"`
- `expression: string|string[]?` → `-e <script>` (repeatable)
- `file: string|string[]?` → `-f <file>` (repeatable)
- `null_data: boolean?` → `-z` (GNU)
- `follow_symlinks: boolean?` → `--follow-symlinks` (GNU)
- `posix: boolean?` → `--posix` (GNU)
- `sandbox: boolean?` → `--sandbox` (GNU)
- `extra: string[]?` → extra argv appended after modeled options

## Examples

### Apply a script to stdin

```lua
local Sed = require("wardlib.app.sed").Sed

-- sed -e 's/foo/bar/g'
local cmd = Sed.script("s/foo/bar/g")
```

### Apply a script to files

```lua
local Sed = require("wardlib.app.sed").Sed

-- sed -E -e 's/foo/bar/g' a.txt b.txt
local cmd = Sed.replace("foo", "bar", { "a.txt", "b.txt" }, { extended = true })
```

### In-place edit

```lua
local Sed = require("wardlib.app.sed").Sed

-- sed -i.bak -e 's/hello/hi/g' file.txt
local cmd = Sed.inplace_replace("hello", "hi", "file.txt", ".bak")
cmd:run()
```

### Multiple expressions

```lua
local Sed = require("wardlib.app.sed").Sed

-- sed -e 's/a/b/g' -e 's/c/d/g' file.txt
local cmd = Sed.run("file.txt", {
  expression = { "s/a/b/g", "s/c/d/g" },
})
```

### Read stdout using `wardlib.tools.out`

```lua
local Sed = require("wardlib.app.sed").Sed
local out = require("wardlib.tools.out")

local txt = out.cmd(Sed.script("s/foo/bar/g"))
  :label("sed")
  :text()
```
