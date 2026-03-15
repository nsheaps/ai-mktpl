---
name: watch-command-lsp
description: >
  Use this skill when you need to understand how the watch-command-lsp plugin works.
  This plugin runs watch commands (test runners, linters, compilers) in the background
  and publishes their parsed diagnostics as native LSP diagnostics, so errors and
  warnings appear inline without re-running full suites.
---

# Watch Command LSP

An LSP server that bridges watch-mode CLI tools into native LSP diagnostics pushed to Claude.

## When to Use

- You need to monitor for test failures while making changes (e.g. TDD workflow)
- You want live lint errors after edits without running the full linter
- You're working with a TypeScript project and want live compiler errors
- You want to watch any command's output for errors matching a pattern

## How It Works

1. The LSP server starts automatically when the plugin is enabled
2. It reads watcher configurations from `initializationOptions` in `.lsp.json`
3. Each watcher spawns its shell command and parses stdout/stderr in real-time
4. Parsed errors are published as `textDocument/publishDiagnostics` notifications
5. Diagnostics appear inline in Claude's context — no polling needed

## Configuring Watchers

Edit `.lsp.json` `initializationOptions.watchers` array:

```json
{
  "watchers": [
    {
      "id": "tsc",
      "command": "npx tsc --watch --noEmit",
      "parser": "tsc"
    },
    {
      "id": "jest",
      "command": "npx jest --watchAll --no-coverage",
      "parser": "jest"
    }
  ]
}
```

### Watcher Fields

| Field           | Required | Description                                         |
| --------------- | -------- | --------------------------------------------------- |
| `id`            | Yes      | Unique identifier (e.g. "jest", "eslint", "tsc")    |
| `command`       | Yes      | Shell command to run                                |
| `parser`        | Yes      | One of: `generic`, `jest`, `eslint`, `tsc`, `regex` |
| `cwd`           | No       | Working directory (defaults to workspace root)      |
| `env`           | No       | Additional environment variables                    |
| `shell`         | No       | Shell to use (defaults to `/bin/sh`)                |
| `regexPatterns` | No       | Custom regex patterns (only for `parser: "regex"`)  |

## Parser Reference

| Parser    | Best For                             | What It Matches                                 |
| --------- | ------------------------------------ | ----------------------------------------------- |
| `generic` | Any tool with `file:line:col` output | GCC, Clang, Go, Rust, etc.                      |
| `jest`    | Jest test runner                     | FAIL blocks, test names, stack traces           |
| `eslint`  | ESLint linter                        | Default formatter output with rule IDs          |
| `tsc`     | TypeScript compiler                  | TS error codes, both `()` and `:` formats       |
| `regex`   | Custom tools                         | User-defined patterns with named capture groups |

## Example Workflows

### TDD with Jest

Configure a jest watcher, then make code changes. Failed tests appear as diagnostics
on the test files automatically. Fix the code and watch the diagnostics clear.

### TypeScript + ESLint

Run both `tsc --watch` and `eslint --watch` simultaneously. Type errors and lint
violations from both tools appear as diagnostics on the relevant files.

### Custom Regex

For tools not covered by built-in parsers, use named capture groups:

```json
{
  "id": "mycheck",
  "command": "my-tool --watch",
  "parser": "regex",
  "regexPatterns": [
    {
      "pattern": "(?<file>[\\w/]+\\.\\w+):(?<line>\\d+):(?<severity>\\w+):(?<message>.*)"
    }
  ]
}
```

Named groups: `file`, `line`, `column`, `message`, `severity`, `code`
