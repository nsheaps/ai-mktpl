# watch-command-lsp

An MCP server plugin that runs watch commands (test runners, linters, compilers) in the background and exposes their parsed diagnostics as MCP tools. Acts as an interface layer between CLI watch-mode tools and Claude, enabling real-time error monitoring without re-running full suites.

## How It Works

1. You start a watcher with a shell command and a parser type
2. The plugin spawns the command and continuously parses its stdout/stderr
3. Errors and warnings are extracted into structured diagnostics
4. Claude queries diagnostics via MCP tools — no hooks injection needed

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

## Quick Start

Once installed, use the MCP tools directly:

```
# Start watching for TypeScript errors
mcp__watch-command-lsp__start_watcher(id="tsc", command="npx tsc --watch --noEmit", parser="tsc")

# Check for errors
mcp__watch-command-lsp__get_diagnostics()

# Stop when done
mcp__watch-command-lsp__stop_watcher(id="tsc")
```

## MCP Tools

| Tool                | Description                                   |
| ------------------- | --------------------------------------------- |
| `start_watcher`     | Start a watch command with a specified parser |
| `stop_watcher`      | Stop a running watcher                        |
| `list_watchers`     | List active watchers and their status         |
| `get_diagnostics`   | Get parsed errors/warnings (filterable)       |
| `get_output`        | Get raw output lines from a watcher           |
| `clear_diagnostics` | Clear accumulated diagnostics                 |

## Supported Parsers

| Parser    | Tools                      | Output Format                          |
| --------- | -------------------------- | -------------------------------------- |
| `generic` | GCC, Clang, Go, Rust, etc. | `file:line:col: severity: message`     |
| `jest`    | Jest                       | `FAIL` blocks with stack traces        |
| `eslint`  | ESLint (default formatter) | Grouped by file with rule IDs          |
| `tsc`     | TypeScript compiler        | `TS` error codes                       |
| `regex`   | Any tool                   | Custom regex with named capture groups |

## Configuration

Settings in `plugins.settings.yaml`:

```yaml
watch-command-lsp:
  enabled: true
```

## Architecture

```
Claude Code ←(stdio/MCP)→ watch-command-lsp server
                               ├→ jest --watchAll (subprocess)
                               ├→ tsc --watch (subprocess)
                               └→ eslint --watch (subprocess)
```

The server manages child processes and their output parsing. Each watcher has:

- A spawned child process
- An output parser matched to the tool's format
- An in-memory diagnostic store
- A ring buffer of raw output lines

## License

MIT
