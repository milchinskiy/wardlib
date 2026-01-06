# Contributing to wardlib

wardlib is an external library intended to be used with Ward. Most of wardlib
consists of thin wrappers around system tools and small composition utilities.

## Design rules

1. **Build commands; do not execute them.** Wrappers should return
   `ward.process.cmd(...)` objects and avoid parsing command output.

2. **Do not mutate caller input.** Treat `opts` tables as immutable inputs.
   If a helper needs to set defaults, clone `opts` first.

3. **Prefer shared helpers for repeated patterns.** Use `util.validate` and
   `util.args` rather than duplicating the same validation and `extra` handling
   in every module.

4. **Do not duplicate Ward functionality.** If Ward already exposes a primitive
   (filesystem checks, env introspection, process execution), use it instead of
   re-implementing.

## Wrapper conventions

* `bin` fields:
  * Default executable name is stored on the wrapper table (`Foo.bin`).
  * Validate with `util.validate.bin(...)` at the top of public entrypoints.

* Options:
  * `opts.extra` is always an array appended after modeled flags.
  * For repeatable options (headers, expressions), accept `string|string[]`.

* Error messages:
  * Prefer consistent labels (e.g. `"curl binary"`, `"url"`, `"timeout"`).
