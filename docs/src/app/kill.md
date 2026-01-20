# app.kill

`app.kill` provides thin command-construction wrappers around common process
termination utilities:

- `kill` — signal processes by PID
- `killall` — signal processes by name
- `pkill` — signal processes by pattern

> This module constructs `ward.process.cmd(...)` invocations; it does not parse output.
> consumers can use `wardlib.tools.out` (or their own parsing) on the `:output()`
> result.

## Import

```lua
local Kill = require("wardlib.app.kill").Kill
```

## Privilege escalation

Signaling processes owned by other users (or PID namespaces) may require
elevated privileges. Prefer `wardlib.tools.with` to make privilege escalation
explicit and scoped.

```lua
local with = require("wardlib.tools.with")

with.with(with.middleware.sudo(), function()
  Kill.pid(1234, "TERM"):run()
end)
```

## Types

- `Signal` — `string|number`
  - Examples: `"TERM"`, `"SIGKILL"`, `9`.

## Options

### `KillOpts`

- `signal: Signal?` — adds `-s <signal>`
- `list: boolean?` — `-l` (list signals; ignores pids)
- `table: boolean?` — `-L` (list signals in a table; not available on all implementations)
- `extra: string[]?` — appended after modeled options

### `KillallOpts`

- `signal: Signal?` — `-s <sig>`
- `exact: boolean?` — `-e` exact match
- `ignore_case: boolean?` — `-I` ignore case
- `interactive: boolean?` — `-i` ask before killing
- `wait: boolean?` — `-w` wait for processes to die
- `regexp: boolean?` — `-r` interpret names as regex
- `user: string?` — `-u <user>`
- `verbose: boolean?` — `-v`
- `quiet: boolean?` — `-q`
- `extra: string[]?` — appended after modeled options

### `PkillOpts`

- `signal: Signal?` — added as `-<sig>` (compact pkill form)
- `full: boolean?` — `-f` match full command line
- `exact: boolean?` — `-x` match whole name
- `newest: boolean?` — `-n` select newest
- `oldest: boolean?` — `-o` select oldest
- `parent: number?` — `-P <ppid>`
- `group: number?` — `-g <pgrp>`
- `session: number?` — `-s <sid>`
- `terminal: string?` — `-t <tty>`
- `user: string?` — `-u <user>`
- `uid: number?` — `-U <uid>`
- `euid: number?` — `-e <euid>` (procps)
- `invert: boolean?` — `-v` invert match
- `count: boolean?` — `-c` count matches
- `list_name: boolean?` — `-l` list pid and name
- `list_full: boolean?` — `-a` list full command line (procps)
- `delimiter: string?` — `-d <delim>` (procps)
- `extra: string[]?` — appended after modeled options

## API

### `Kill.kill(pids, opts)`

Construct a `kill` command.

Builds: `kill <opts...> [pids...]`

```lua
Kill.kill(pids: number|number[]|string|string[]|nil, opts: KillOpts|nil) -> ward.Cmd
```

Notes:

- If `pids` is `nil`, the command is built with only options (useful for `-l`).

### `Kill.killall(names, opts)`

Builds: `killall <opts...> [names...]`

```lua
Kill.killall(names: string|string[]|nil, opts: KillallOpts|nil) -> ward.Cmd
```

### `Kill.pkill(pattern, opts)`

Builds: `pkill <opts...> [pattern]`

```lua
Kill.pkill(pattern: string|nil, opts: PkillOpts|nil) -> ward.Cmd
```

### Convenience helpers

- `Kill.pid(pid, sig)` — `kill -s <sig> <pid>`
- `Kill.by_name(name, sig)` — `killall -s <sig> <name>`
- `Kill.by_pattern(pattern, sig, full)` — `pkill [-f] -<sig> <pattern>`

## Examples

### Kill a PID with SIGTERM

```lua
-- kill -s TERM 123
Kill.pid(123, "TERM"):run()
```

### Kill multiple PIDs

```lua
-- kill -s KILL 100 101 102
Kill.kill({ 100, 101, 102 }, { signal = "KILL" }):run()
```

### Kill by process name

```lua
-- killall -s 9 firefox
Kill.by_name("firefox", 9):run()
```

### Kill by pattern (full command line)

```lua
-- pkill -KILL -f "ssh .* -N"
Kill.by_pattern("ssh .* -N", "KILL", true):run()
```

### List available signals and parse output

```lua
local out = require("wardlib.tools.out")

local lines = out.cmd(Kill.kill(nil, { list = true }))
  :label("kill -l")
  :lines()

-- `lines` contains the signal list; format depends on kill implementation.
```

### Count matching processes with `pkill -c`

```lua
local out = require("wardlib.tools.out")

-- pkill -c -f 'ssh .* -N'
local n = out.cmd(Kill.pkill("ssh .* -N", { count = true, full = true }))
  :label("pkill -c -f ...")
  :trim()
  :line()

-- `n` is a string; convert to number if needed.
```
