# Changelog

## [0.0.1] - 2026-01-20

## [0.0.1] - 2026-01-20

## [0.0.1] - 2026-01-20

## [0.0.1] - 2026-01-20

## [0.0.1] - 2026-01-20

All notable changes to this project will be documented in this file. See [commit-and-tag-version](https://github.com/absolute-version/commit-and-tag-version) for commit guidelines.

## 0.1.1 (2026-01-19)

### Bug Fixes

- Use osascript instead of escape sequences for iTerm2 badge updates. Claude Code captures subprocess stdout/stderr, preventing escape sequences from reaching the terminal. osascript talks directly to iTerm2 via macOS scripting bridge, bypassing this limitation.

## 0.1.0 (2026-01-19)

### Features

- Initial release - fork of statusline plugin with iTerm2 badge integration
- Sets `user.badge` variable with repo/branch/ahead-behind/dirty status
- Badge updates on every statusline refresh
- Gracefully degrades when not running in iTerm2
