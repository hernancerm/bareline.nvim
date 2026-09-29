# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Vimscript function `BlItem()` to draw an item, e.g. `%{BlItem('filepath')}`.

### Changed

- Config key `statusline.value` is now just `statusline`.
- Calling `setup()` is no longer required. Call it only to configure the plugin.
- Requires Neovim 0.12.
- Items shared by several statuslines create their autocmds only once.

### Removed

- Config key `statusline.items`. Items drawn with `BlItem()` need no registration.
- Config key `logging`, and with it the log file.

### Fixed

- The statusline is refreshed on `:terminal`.
- Wrong statusline right after calling `setup()`.
- Unreadable `jdt://` buf names in item `filepath`. The URI query string is dropped.
- Wrong statusline in a new inactive window.
- Stale statusline when text is streamed to a buf with a delay.

## [0.2.0] - 2025-04-13

### Added

- Items, which set buf-local vars read by the statusline. All items are async.
- Vimscript helper functions: `BlIs()`, `BlPad()`, `BlPadl()`, `BlPadr()`, `BlWrap()`, `BlIna()`,
  `BlInahide()` and `BlInarm()`.
- Item `mhr`, which fixes the whitespace between `%m%h%r`.
- Item `current_working_dir`.
- Support for detached and linked Git work trees.
- Optional logging of statusline redraws.

### Changed

- Components were redesigned into items. The way statuslines are defined in `setup()` changed.
- Requires Neovim 0.11.
- Item `lsp_servers` is async.
- Item `git_head` requires Git to be installed.
- Item `file_path_relative_to_cwd` renamed to `filepath`.
- The home directory is shortened to `~`.
- Item `vim_mode` differentiates the visual modes.
- The statusline is not redrawn while the cursor is on a floating window.

### Removed

- `BareComponent:mask()`, replaced by the `mask` option.

### Fixed

- Mode shown as terminal after closing fzf-lua's `live_grep()` with `<Esc>`.
- Item `git_head` uses the work tree toplevel.
- Item `plugin_name` failing when `w:quickfix_title` is undefined.

## [0.1.0] - 2024-09-17

Initial release.

### Added

- Statuslines for active, inactive and plugin windows.
- Components `vim_mode`, `plugin_name`, `indent_style`, `end_of_line`, `git_head`, `lsp_servers`,
  `file_path_relative_to_cwd`, `diagnostics` and `position`.
- Custom components through `BareComponent`.
- Redraws as changes happen, without a timer.

[Unreleased]: https://github.com/hernancerm/bareline.nvim/compare/0.2.0...HEAD
[0.2.0]: https://github.com/hernancerm/bareline.nvim/compare/0.1.0...0.2.0
[0.1.0]: https://github.com/hernancerm/bareline.nvim/releases/tag/0.1.0
