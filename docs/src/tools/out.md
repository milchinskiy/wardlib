# out

`wardlib.tools.out` provides a fluent, fail-fast way to parse `ward.process`
command output.

It wraps either:

- a `ward.process` command object (lazy, executes once via `:output()`), or
- an already captured `CmdResult`.

The API is intentionally small: chainable configuration methods, followed by a
terminal extractor.

## Basic usage

```lua
local p = require("ward.process")
local out = require("wardlib.tools.out")

local sha = out.cmd(p.cmd("git", "rev-parse", "HEAD"))
  :label("git rev-parse HEAD")
  :trim()
  :line()
```

## Wrapping an existing CmdResult

```lua
local out = require("wardlib.tools.out")

local res = require("ward.process").cmd("uname", "-r"):output()
local kernel = out.res(res):trim():line()
```

## Selecting stderr and allowing failures

By default, `out` requires `res.ok == true` and reads from `stdout`.

```lua
local out = require("wardlib.tools.out")
local p = require("ward.process")

local diagnostics = out.cmd(p.cmd("some-tool", "--diagnose"))
  :stderr()
  :allow_fail()
  :text()
```

## Structured decoders

If a command can output machine-readable data, prefer that and decode it.

```lua
local out = require("wardlib.tools.out")
local p = require("ward.process")

local data = out.cmd(p.cmd("ip", "-j", "addr"))
  :label("ip -j addr")
  :json()
```

Supported decoders (via `ward.convert.*.decode`):

- `:json()`
- `:yaml()`
- `:toml()`
- `:ini()`

## Reference

### Constructors

- `out.cmd(cmd)` wraps a command (expects `cmd:output()`), executes lazily,
caches the result.
- `out.res(res)` wraps a captured result table.

### Chainable configuration

- `:label(string)` used in error messages.
- `:stdout()` / `:stderr()` selects which stream to parse (default: stdout).
- `:ok()` requires `res.ok == true` (default).
- `:allow_fail()` disables the `ok` requirement.
- `:trim()` / `:ltrim()` / `:rtrim()` whitespace trimming applied before extraction.
- `:normalize_newlines(true|false)` convert CRLF/CR to LF (default: true).
- `:max_preview(nbytes)` limit output previews in error messages (default: 2048).

### Terminal extractors

- `:text()` returns a string.
- `:lines()` returns `string[]` split by `\n` (ignores a trailing empty line
when output ends with a newline).
- `:line()` returns a single line, errors when output is empty or multi-line.
- `:match(pattern)` returns captures like `string.match` (errors when no match).
- `:matches(pattern)` returns all matches as an array.
- `:json()` / `:yaml()` / `:toml()` / `:ini()` decodes structured output.
