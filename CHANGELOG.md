# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-10-22

### Added

- The Shelf interface, which fits the shape of the widget: the install options open as a sheet, in place under the row, as a full panel, beside the list or as a strip under the viewport.
- Install any version of a package into the shared or server realm under a name of your choosing, with each step shown as it resolves, downloads and writes.
- Update, roll back and remove installed packages from the Installed tab, with Undo and Show in Explorer after every change.
- Installs resolve through a port of Wally's resolver and land in Wally's own layout under `_Plugin_Index`, with each realm's requests kept in the place manifest.
- A warning when something other than the plugin removes `_Plugin_Index`.
- Colours from the Studio theme, with the Wally red as the accent, and motion that honours Roblox's reduced motion setting.

### Changed

- Dependencies are managed with pesde instead of Wally.
- Luau sources use the `.luau` extension.

### Removed

- The right-click menus on search results and installed packages; the widget installs and removes packages itself.
- The full-screen loading overlay; a surface shows its own busy state while an install runs.

[Unreleased]: https://github.com/4x8Matrix/Wally-Plugin/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/4x8Matrix/Wally-Plugin/compare/v1.0.0-rc.1...v0.1.0
