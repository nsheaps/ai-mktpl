---
name: watch-command-lsp
description: >
  Use this skill when you need to monitor a project for live errors, test failures,
  or lint warnings without re-running full test suites or lint passes. The watch-command-lsp
  plugin runs watch commands in the background and exposes their parsed diagnostics
  as MCP tools you can query at any time.
---

# Watch Command LSP

An MCP server that bridges watch-mode CLI tools (test runners, linters, compilers) into structured diagnostics that Claude can query in real-time.

## When to Use

- You need to monitor for test failures while making changes (e.g. TDD workflow)
- You want to check lint errors after edits without running the full linter
- You're working with a TypeScript project and want live compiler errors
- You want to watch any command's output for errors matching a pattern

## Available MCP Tools

All tools are prefixed with `mcp__watch-command-lsp__`.

### `start_watcher`

Start a watch command. Required parameters:

| Parameter | Type   | Description                                         |
| --------- | ------ | --------------------------------------------------- |
| `id`      | string | Unique identifier (e.g. "jest", "eslint", "tsc")    |
| `command` | string | Shell command to run                                |
| `parser`  | string | One of: `generic`, `jest`, `eslint`, `tsc`, `regex` |

Optional: `cwd`, `env`, `regexPatterns`

### `stop_watcher`

Stop a running watcher by `id`.

### `list_watchers`

Show all active watchers with status, PID, and diagnostic counts.

### `get_diagnostics`

Get current errors/warnings. Optional filters: `id`, `severity`, `file`.

Returns structured data:

```json
{
  "count": 2,
  "diagnostics": [
    {
      "file": "src/index.ts",
      "line": 10,
      "column": 5,
      "severity": "error",
      "message": "Type 'string' is not assignable to type 'number'",
      "source": "tsc",
      "code": "TS2322"
    }
  ]
}
```

### `get_output`

Get raw output lines from a watcher. Parameters: `id` (required), `lines` (default: 50).

### `clear_diagnostics`

Clear accumulated diagnostics for a watcher by `id`.

## Workflow Patterns

### TDD with Jest

```
1. start_watcher(id="jest", command="npx jest --watchAll --no-coverage", parser="jest")
2. Make code changes
3. get_diagnostics(id="jest") → see which tests fail
4. Fix the code
5. get_diagnostics(id="jest") → verify tests pass
6. stop_watcher(id="jest") when done
```

### Lint-as-you-go with ESLint

```
1. start_watcher(id="eslint", command="npx eslint --watch src/", parser="eslint")
2. Edit files
3. get_diagnostics(id="eslint", severity="error") → see only errors
4. Fix issues, clear_diagnostics(id="eslint")
5. get_diagnostics(id="eslint") → check for new issues
```

### TypeScript Compiler Watch

```
1. start_watcher(id="tsc", command="npx tsc --watch --noEmit", parser="tsc")
2. get_diagnostics(id="tsc", file="src/utils.ts") → errors in a specific file
```

### Multiple Watchers

You can run multiple watchers simultaneously:

```
1. start_watcher(id="tsc", command="npx tsc --watch --noEmit", parser="tsc")
2. start_watcher(id="jest", command="npx jest --watchAll", parser="jest")
3. get_diagnostics() → all errors from both watchers
4. get_diagnostics(severity="error") → only errors across all watchers
```

## Parser Reference

| Parser    | Best For                             | What It Matches                                 |
| --------- | ------------------------------------ | ----------------------------------------------- |
| `generic` | Any tool with `file:line:col` output | GCC, Clang, Go, Rust, etc.                      |
| `jest`    | Jest test runner                     | FAIL blocks, test names, stack traces           |
| `eslint`  | ESLint linter                        | Default formatter output with rule IDs          |
| `tsc`     | TypeScript compiler                  | TS error codes, both `()` and `:` formats       |
| `regex`   | Custom tools                         | User-defined patterns with named capture groups |

## Custom Regex Parser

For tools not covered by built-in parsers, use the `regex` parser with named capture groups:

```
start_watcher(
  id="mycheck",
  command="my-custom-tool --watch",
  parser="regex",
  regexPatterns=[{
    "pattern": "(?<file>[\\w/]+\\.\\w+)\\|(?<line>\\d+)\\|(?<severity>\\w+)\\|(?<message>.*)"
  }]
)
```

Named groups: `file`, `line`, `column`, `message`, `severity`, `code`
