# kill

Wrappers around process termination utilities:

- `kill` — signal processes by PID
- `killall` — signal processes by name
- `pkill` — signal processes by pattern

The wrappers construct a `ward.process.cmd(...)` invocation; they do not parse output.

## Kill a PID with SIGTERM

```lua
local Kill = require("wardlib.app.kill").Kill

-- Equivalent to: kill -s TERM 123
local cmd = Kill.kill(123, { signal = "TERM" })
```

## Force-kill by name

```lua
local Kill = require("wardlib.app.kill").Kill

-- Equivalent to: killall -s 9 firefox
local cmd = Kill.by_name("firefox", 9)
```

## Kill by pattern (full command line)

```lua
local Kill = require("wardlib.app.kill").Kill

-- Equivalent to: pkill -KILL -f "ssh .* -N"
local cmd = Kill.by_pattern("ssh .* -N", "KILL", true)
```

## List available signals

```lua
local Kill = require("wardlib.app.kill").Kill

-- Equivalent to: kill -l
local cmd = Kill.kill(nil, { list = true })
```
