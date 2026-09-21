# watch-command-lsp

An LSP server plugin that runs watch commands (test runners, linters, compilers) in the background and publishes their parsed output as LSP diagnostics. Claude sees live errors and warnings natively — no MCP tools to query, no hooks to inject.

## How It Works

1. Claude Code starts the LSP server when the plugin is enabled
2. The server reads watcher configurations from `initializationOptions` in `.lsp.json`
3. Each watcher spawns a shell command and continuously parses its stdout/stderr
4. Parsed errors and warnings are pushed to Claude as `textDocument/publishDiagnostics` notifications
5. Claude sees diagnostics inline, just like a real language server

## Installation

This plugin is part of the [nsheaps/ai-mktpl](https://github.com/nsheaps/ai-mktpl) marketplace. Install it via Claude Code plugin management.

### Prerequisites

- Node.js 18+ or Bun
- The watch command tools you want to use (jest, eslint, tsc, etc.)

### Build

```bash
cd plugins/watch-command-lsp
bun install
bun run build
```

## Configuration

Watchers are configured in `.lsp.json` via `initializationOptions`. The default `.lsp.json` ships with an empty watchers array. To add watchers, either:

**Option A: Edit `.lsp.json` directly** (in the plugin directory):

```json
{
  "watch-command-lsp": {
    "command": "node",
    "args": ["${CLAUDE_PLUGIN_ROOT}/bin/server.mjs", "--stdio"],
    "transport": "stdio",
    "extensionToLanguage": {
      ".ts": "typescript",
      ".js": "javascript"
    },
    "initializationOptions": {
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
  }
}
```

**Option B: Project-level override** in `.claude/plugins.settings.yaml`:

```yaml
watch-command-lsp:
  watchers:
    - id: eslint
      command: "npx eslint --watch src/"
      parser: eslint
    - id: tsc
      command: "npx tsc --watch --noEmit"
      parser: tsc
```

### Watcher Configuration Fields

| Field           | Required | Description                                         |
| --------------- | -------- | --------------------------------------------------- |
| `id`            | Yes      | Unique identifier (e.g. "jest", "eslint", "tsc")    |
| `command`       | Yes      | Shell command to run                                |
| `parser`        | Yes      | One of: `generic`, `jest`, `eslint`, `tsc`, `regex` |
| `cwd`           | No       | Working directory (defaults to workspace root)      |
| `env`           | No       | Additional environment variables                    |
| `shell`         | No       | Shell to use (defaults to `/bin/sh`)                |
| `regexPatterns` | No       | Custom regex patterns (only for `parser: "regex"`)  |

## Supported Parsers

| Parser    | Best For                             | What It Matches                                 |
| --------- | ------------------------------------ | ----------------------------------------------- |
| `generic` | Any tool with `file:line:col` output | GCC, Clang, Go, Rust, etc.                      |
| `jest`    | Jest test runner                     | FAIL blocks, test names, stack traces           |
| `eslint`  | ESLint linter                        | Default formatter output with rule IDs          |
| `tsc`     | TypeScript compiler                  | TS error codes, both `()` and `:` formats       |
| `regex`   | Custom tools                         | User-defined patterns with named capture groups |

### Custom Regex Parser

For tools not covered by built-in parsers:

```json
{
  "id": "mycheck",
  "command": "my-custom-tool --watch",
  "parser": "regex",
  "regexPatterns": [
    {
      "pattern": "(?<file>[\\w/]+\\.\\w+)\\|(?<line>\\d+)\\|(?<severity>\\w+)\\|(?<message>.*)"
    }
  ]
}
```

Named capture groups: `file`, `line`, `column`, `message`, `severity`, `code`

## Architecture

```
Claude Code ←(stdio/LSP)→ watch-command-lsp server
                               ├→ jest --watchAll    (subprocess, parsed by JestParser)
                               ├→ tsc --watch        (subprocess, parsed by TscParser)
                               └→ eslint --watch     (subprocess, parsed by EslintParser)
                                        ↓
                          textDocument/publishDiagnostics → Claude
```

The server implements the Language Server Protocol over stdio. It manages child processes and their output parsing. Each watcher has:

- A spawned child process
- An output parser matched to the tool's format
- Diagnostics published per-file to the LSP client

Unlike an MCP-based approach, diagnostics are pushed proactively — Claude doesn't need to poll or query for them.

## License

MIT
