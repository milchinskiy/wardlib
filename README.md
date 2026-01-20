# wardlib

**wardlib** is an external extension of
[Ward](https://github.com/milchinskiy/ward)'s core module set.
Ward ships intentionally small; **wardlib** is where we add higher-level
batteries (apps and tools), iterate quickly, and converge on best-practice
scripting patterns.

If you are writing Ward scripts and want:

- stable wrappers around common CLI programs (package managers, system tools, etc.),
- opinionated tools for CLI parsing, retries, idempotent tasks, and environment checks,
- cookbook-style examples you can copy into real scripts,

this repository is for you.

---

## Repository layout

- `wardlib/` — Lua modules exposed via `require("wardlib.…")`
  - `wardlib/app/*` — wrappers around specific CLI applications
  - `wardlib/tools/*` — reusable building blocks (ensure, with, out, retry, …)
- `docs/` — documentation (mdBook)

---

## Installation

You have a few supported ways to consume wardlib. Choose the one that matches
your workflow.

### 1) Add as a Ward git module (recommended)

Use Ward's `ward.module.git(...)` mechanism to pin a version in your project.

### 2) Git submodule

Add wardlib as a submodule and ensure the `wardlib/` directory is on the
Lua/Ward `package.path`.

### 3) Vendor / copy

Copy the specific modules you need into your repository.

Notes:

- wardlib is a library: it does not install binaries for you. Use your OS
package manager.
- Many app wrappers assume their underlying executable is available
(see `wardlib.tools.ensure`).

---

## Quick start

### 1) Make assumptions explicit (fail fast)

Most automation scripts have implicit requirements (OS, tools, env vars, privileges).
Declare them early with `wardlib.tools.ensure`:

```lua
local ensure = require("wardlib.tools.ensure")

ensure.os("linux")
ensure.bins({ "git", "tar", "ssh" })

local token = ensure.env("TOKEN")
```

### 2) Privilege escalation: use middleware (not `{ sudo = true }`)

wardlib app wrappers intentionally do **not** embed sudo logic. Use
`wardlib.tools.with` so privilege escalation is explicit, scoped, and predictable:

```lua
local with = require("wardlib.tools.with")
local AptGet = require("wardlib.app.aptget").AptGet

with.with(with.middleware.sudo(), function()
  AptGet.update({ assume_yes = true }):run()
  AptGet.install({ "curl", "jq" }, { assume_yes = true }):run()
end)
```

### 3) Parse command output consistently

Use `wardlib.tools.out` to turn `CmdResult.stdout` into something useful
(text, lines, JSON, …):

```lua
local p = require("ward.process")
local out = require("wardlib.tools.out")

local sha = out.cmd(p.cmd("git", "rev-parse", "HEAD"))
  :label("git rev-parse HEAD")
  :trim()
  :line()
```

---

## Documentation

The documentation lives under `docs/` (mdBook).

Build it locally:

```sh
cd docs
mdbook build
```

Start a live-reload server:

```sh
cd docs
mdbook serve
```

Or read online: [wardlib docs](https://milchinskiy.github.io/wardlib)

The docs include:

- **Apps**: wrappers around CLI programs (`wardlib.app.*`)
- **Tools**: reusable primitives (`wardlib.tools.*`)
- **Cookbook**: real-life, end-to-end examples

---

## Conventions (important)

wardlib aims to keep scripts reliable and predictable. A few conventions are
enforced by example and documentation:

- **App modules build commands** and return `ward.process.cmd(...)` objects;
they do not hide side effects.
- **Privilege escalation is external** (`wardlib.tools.with.middleware.sudo()/doas()`).
- Prefer **machine-readable output** from CLIs (`--json`, `-J`, etc.), then
decode it with `wardlib.tools.out`.
- Validate environment assumptions early (`wardlib.tools.ensure`).

---

## Tests

Run the test suite with:

```sh
ward run run-tests.lua -- "**/*.test.lua"
```

---

## Contributing

Contributions are welcome.

- Keep modules small, composable, and Lua-native.
- Update docs for every public API change.
- Add tests for non-trivial behavior.
- Prefer improving existing tools over adding near-duplicates.

See `CONTRIBUTING.md` for more.

---

## License

Dual-licensed under MIT and Apache-2.0. See `LICENSE-MIT` and `LICENSE-APACHE`.
