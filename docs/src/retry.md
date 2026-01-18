# tools.retry

`tools.retry` is a small wardlib wrapper around Ward core `ward.helpers.retry`.

It provides a stable wardlib-facing API, option aliases, and a
`should_retry(err)` hook to stop retries early.

## API

```lua
local retry = require("wardlib.tools.retry")
```

### `retry.call(fn, opts?) -> any`

Runs `fn()` and retries when it raises an error.

Options (`opts` table, all optional):

- `tries` or `attempts` (integer, default: Ward core default)
  - Only one of these may be specified.
  - Values <= 0 are treated as 1.
- `delay` (duration, default: Ward core default)
  - Passed through to Ward core. May be a number (milliseconds) or a duration
  string (for example: `"100ms"`, `"2s"`).
- `max_delay` (duration)
  - Passed through to Ward core.
- `max` (duration)
  - Alias for `max_delay`.
- `backoff` (number)
  - Passed through to Ward core.
- `jitter` (boolean)
  - Passed through to Ward core.
- `jitter_ratio` (number)
  - Passed through to Ward core.
- `should_retry(err)` (function)
  - When set, this function is called with the error raised by `fn()`.
  - If it returns `false`, the retry loop stops immediately and the original
  error is raised.

Example:

```lua
local retry = require("wardlib.tools.retry")

local value = retry.call(function()
  local r = require("ward.process").cmd("curl", "-fsS", "https://example.com"):output()
  if not r.ok then
    error("network")
  end
  return r.stdout
end, {
  tries = 5,
  delay = "200ms",
  backoff = 2.0,
  max_delay = "3s",
  jitter = true,
  should_retry = function(err)
    -- do not retry for hard failures
    return tostring(err) ~= "bad credentials"
  end,
})
```

### `retry.pcall(fn, opts?) -> (ok, value_or_err)`

Like `retry.call`, but returns a boolean success flag.

```lua
local retry = require("wardlib.tools.retry")

local ok, v = retry.pcall(function()
  error("boom")
end, { tries = 3, delay = 0 })

if not ok then
  print("failed: " .. tostring(v))
end
```
