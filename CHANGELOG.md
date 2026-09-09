# Changelog

## Unreleased

### Added

- Julia support for scripts and Quarto documents, including Julia command
  generation and Jupyter kernel detection.

## [1.2.1] - 2026-09-01

### Fixed

- Documented and enforced minimum Neovim version raised from 0.7.0 to
  0.11.0, to match what `health.lua` (added in 1.2.0) actually requires:
  `vim.health.start/ok/warn/error` aren't available on older versions.

## [1.2.0] - 2026-09-01

### Added

- `:checkhealth slime_peek` support: checks the Neovim version, whether
  `vim-slime` is installed, and whether `setup()` was passed any unrecognised
  configuration keys.
- `setup()` now validates the type of its options and raises a clear error on
  invalid input (e.g. a non-boolean `use_yaml_language`), instead of silently
  accepting it.

### Fixed

- User commands (`:PeekHead`, etc.) now exist as soon as Neovim starts,
  independent of whether `setup()` is ever called — previously they only existed
  as a side effect of calling `setup()`.
- The plugin now actually aborts on unsupported Neovim versions, instead of
  printing an error and continuing anyway.
- Plugin module loading is now deferred until a command is actually invoked,
  rather than happening unconditionally at start-up

### Changed

- Doc comments converted from plain LDoc-style comments to LuaCATS
  annotations (`---@param`, `---@return`, `---@class`), enabling
  type-checking and completion via `lua-language-server`.

## [1.1.0] - 2025-11-28

### Added

- Operator/motion-mode variants of every command (`peek_head_motion`,
  `:PeekHeadMotion`, _etc._), letting any operator, motion, or text object be
  sent to the REPL — not just the word under the cursor.

### Changed

- Plugin internals refactored from a single file into separate Lua submodules
  (`commands.lua`, `lang.lua`, `util.lua`) for maintainability.

## [1.0.0] - 2025-06-27

Initial stable release.

- `PeekHead`, `PeekTail`, `PeekNames`, `PeekDims`, `PeekTypes`, `PeekHelp`
  commands (and matching Lua functions), operating on the word under the cursor.
- Automatic language detection for R and Python across plain scripts, R
  Markdown, and Quarto documents (by code-chunk language or, optionally, the
  document's YAML header).
- `setup(opts)` configuration, with `use_yaml_language` as the first option.
- Requires Neovim >= 0.7.0.
