# dotfiles

Declarative dotfiles management for Ward scripts.

A dotfiles *definition* is an **ordered list of explicit step records**.
Ordering is always preserved because `steps` is a plain array.

Design goals:

* Deterministic: steps run in the exact order you provide.
* Safe by default: existing destinations are not modified unless you pass
`force = true`.
* Best-effort revert: changes are recorded in a manifest under the target root.

## Quick start

```lua
local dotfiles = require("wardlib.tools.dotfiles")
local tpl = require("ward.template.minijinja").render

local username = "alex"

local def = dotfiles.define("My dotfiles", {
  description = "Minimal personal config",
  steps = {
    dotfiles.content(
      ".config/git/config",
      tpl(
        [[
[user]
  name = {{ username }}
        ]],
        { username = username }
      )
    ),

    dotfiles.link(
      ".config/fish",
      "~/.dotfiles/fish",
      { recursive = true }
    ),

    dotfiles.assert(function(base)
      -- guardrails
      return base ~= "/"
    end, "refusing to apply dotfiles into /"),
  },
})

def:apply("/home/alex", { force = true })
-- def:revert("/home/alex")
```

## Definitions

Create a definition with:

```lua
local dotfiles = require("wardlib.tools.dotfiles")

local def = dotfiles.define("Preset name", {
  description = "Optional description",
  defaults = { ... }, -- reserved for future use
  steps = { ... },   -- required; must be a non-empty array
})
```

Notes:

* `name` is used for identification in the manifest.
* `description` is recorded in the manifest; it does not affect behavior.
* `defaults` is accepted and stored on the definition, but is not currently
used by the engine.
* `steps` must be a non-empty array. Only step records (created by the functions
below) and nested definitions are allowed.

## Path rules

For any destination `rel_path`:

* Must be relative (no leading `/`, `\`, or `C:\...`).
* Must not contain parent traversal (`..`).
* Path separators are normalized internally.

For any `source` path in `dotfiles.link()`:

* `~` and `~/...` are expanded using `$HOME` when available.
* Both absolute and relative paths are allowed.

## Conditional execution (common option)

Most step constructors accept `opts` and support conditional execution:

* `opts.when(base) -> boolean` or `opts.conditions(base) -> boolean`

If provided and returns `false`, the step is skipped.
If the function errors, the apply operation errors.

`base` is the root path you passed to `def:apply(base, ...)`.

## Steps reference

### dotfiles.content(rel_path, content, opts?)

Writes file content to `base/rel_path`.

* `content` may be:

  * a `string`
  * a function `(base, abs) -> string`

Overwrite behavior:

* If destination does not exist: it is created (parent directories are created
automatically).
* If destination is a directory: the step errors.
* If destination exists:

  * without `force=true` on `def:apply`, the step errors
  * with `force=true`, an existing file is overwritten; an existing symlink is
  unlinked first

The tool never writes through an existing destination symlink.

There are no dotfiles-specific file mode/permissions options; use your existing
Ward FS tooling in a `custom` step if you need chmod/chown.

### dotfiles.link(rel_path, source, opts?)

Creates a symlink at `base/rel_path` pointing to `source`.

Options:

* `recursive = true`

  * If `source` is a directory, the destination is ensured to be a directory.
  * The tool walks the source tree and creates symlinks for all non-directory entries.
  * Intermediate directories are created under the destination.
  * Source directory entries are processed in sorted order for determinism.

Replacement policy flags (only relevant with `def:apply(..., { force = true })`):

* `replace_file` (default `true`)

  * Allows replacing an existing regular file at the destination.
* `replace_symlink` (default `true`)

  * Allows replacing an existing symlink at the destination.
* `replace_dir` (default `false`)

  * Allows replacing an existing directory at the destination, but only if the
  directory is empty.

Notes:

* Without `force=true`, any existing destination causes an error.
* Destination symlinks are never followed. In force mode, an existing symlink
is removed before creating the new link.
* If `recursive=true`, directories in the source that are symlinks are treated
as non-directories (a symlink is created for them).

### dotfiles.custom(rel_path_or_nil, fn, opts?)

Runs custom logic.

Signature:

* If `rel_path_or_nil` is a string, `fn(base, abs)` is called where `abs = base/rel_path_or_nil`.
* If `rel_path_or_nil` is `nil`, `fn(base, nil)` is called.

Return values:

* `nil`

  * Treated as an imperative step. It is recorded in the manifest as
  `kind = "exec"` and is not revertable.
* `string`

  * Only valid when a path was provided. The string is treated as file content
  and written to `abs` (using the same overwrite rules as `dotfiles.content`).
* `DotfilesDefinition`

  * Applied as a nested definition.
* `table`

  * If it has `steps = {...}`: treated as a meta table and converted to a definition.
  * Otherwise: treated as a `steps[]` array.

Nested application rules:

* If a path was provided: nested steps are applied under that path (i.e. `abs`
becomes the nested base).
* If no path was provided: nested steps are applied under `base`.

### dotfiles.include(prefix_or_nil, def_or_meta, opts?)

Includes another definition under an optional prefix.

* `def_or_meta` can be:

  * a `DotfilesDefinition` returned by `dotfiles.define()`
  * a meta table `{ name?, description?, defaults?, steps = {...} }`
* If `prefix_or_nil` is non-nil, the included definition is applied under `base/prefix_or_nil`.

### dotfiles.group(name, steps, opts?)

Pure organizational wrapper that preserves ordering.

* `steps` is a steps array.
* `opts.when/conditions` can be used to gate the entire group.
* The group name is for readability in code; it is not currently persisted in
the manifest.

### dotfiles.assert(predicate, message, opts?)

Fail-fast precondition check.

* `predicate(base) -> boolean`
* If it returns false, the apply operation errors with `message`.
* Assertions are recorded in the manifest but are not reverted.

## Applying and reverting

### def:apply(base, opts?)

Applies the definition into `base`.

Options:

* `force = true`

  * Allows replacing existing files/symlinks and (with `replace_dir=true`)
  empty directories.
  * Without `force=true`, any destination that already exists causes an error.
* `manifest_path = "..."`

  * Override the manifest location.
  * Default: `<base>/.ward/dotfiles-manifest.json`.

Side effects and caveats:

* Parent directories are created automatically using
`ward.fs.mkdir(..., { recursive = true })`.
* The dotfiles tool does not attempt atomic writes or compare content hashes;
a write in force mode always overwrites the file.
* There is no built-in backup strategy.

Return value:

* Returns the manifest table that was written.

### def:revert(base, opts?)

Reverts using the stored manifest.

Options:

* `manifest_path = "..."` (must match what was used on apply).

Revert rules:

* Only manifest entries that have `{ path = ..., prev = ... }` are reverted.

  * `exec` (imperative custom) and `assert` entries are not reverted.
* If a path previously did not exist, revert removes it.

  * Directories are removed only if they are empty.
* If a path previously was a symlink, revert restores the previous symlink target.
* If a path previously was a file, revert restores the previous content.
* If a path previously was a directory, revert ensures the directory exists.

At the end of revert, the manifest file is removed. The `<base>/.ward`
directory is removed only if it becomes empty.

## Manifest

By default the manifest is written to:

* `<base>/.ward/dotfiles-manifest.json`

The manifest contains:

* definition metadata (`name`, optional `description`)
* `applied_at` timestamp
* `base`
* a list of `entries` in apply order

Each revertable entry records a snapshot of the previous state:

* `absent`
* `file` with previous content
* `symlink` with previous target
* `dir`

## Limitations

* Revert is best-effort and intentionally conservative; it does not delete
non-empty directories.
* Recursive linking can create many manifest entries (one per created directory
and one per linked leaf).
* Destination conflicts are treated as errors; there is no "plan" or "diff"
mode yet.
