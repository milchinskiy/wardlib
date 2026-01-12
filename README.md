# wardlib

**wardlib** is an external extension (**early stage**) of
[Ward](https://github.com/milchinskiy/ward)'s "standard library".

Ward ships with a small core set of modules. **wardlib** lives outside the Ward
repository and exists to:

- provide additional batteries (modules, helpers, utilities),
- experiment and iterate faster than core,
- give the community a shared place to publish and maintain extensions.

## What you'll find here

- Reusable Ward/Lua modules that can be consumed via `require(...)`
- Optional integrations and convenience helpers
- Examples and documentation for contributed packages

## Installation

This repository is intended to be used as a *library* alongside Ward projects.
Common approaches:

- add it via builtin [Ward](https://github.com/milchinskiy/ward)'s `ward.module.git(...)`,
- add it as a git submodule,
- vendor/copy the modules you need,
- or otherwise place it on your Lua/Ward `package.path` so `require(...)` can
find it.

Exact setup may vary by project; see repository folders and module docs for details.

## Contract pattern (recommended)

Most Ward scripts have implicit assumptions (OS, required binaries, required
env vars, root privileges). `tools.ensure` lets you make those assumptions
explicit and fail fast with clear errors.

Put this at the top of your script:

```lua
local ensure = require("tools.ensure")

-- Declare assumptions early
ensure.os("linux")
ensure.bins({ "git", "tar", "ssh" })

local token = ensure.env("TOKEN")

-- If privileged operations are required:
-- ensure.root()
```

Many wardlib wrappers also use `tools.ensure.bin(...)` internally to validate
their underlying binaries.

## Tests

Run tests with:

```sh
ward run run-tests.lua -- "**/*.test.lua"
```

## Contributing

Contributions are welcome.

- Keep modules small, composable, and Lua-native in style.
- Include a short doc comment or README for new modules.
- Add tests/examples when practical.

## License

See `LICENSE-MIT` and `LICENSE-APACHE` for licensing details.
