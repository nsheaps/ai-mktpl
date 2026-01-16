# Claude Simple CLI Plugin

A simplified one-shot text-based interface over Claude's JSON mode.

## Purpose

This tool provides a simple way to interact with Claude in one-shot mode:

- Each invocation is a new session (no persistent state)
- Text input/output (converts JSON internally)
- Suitable for scripts, piping, and quick queries
- Session continuity via `--resume` flag (not process persistence)

**Note:** Since this runs in one-shot mode, it does NOT need `claude-wrapper`. Use `claude-wrapper` for interactive CLI sessions instead.

## Installation

This plugin is part of the nsheaps/.ai marketplace. The binary is automatically symlinked to your PATH via the SessionStart hook.

## Usage

```bash
claude-simple-cli [OPTIONS] [PROMPT]
```

## Options

| Option            | Description                                       |
| ----------------- | ------------------------------------------------- |
| `--resume <id>`   | Resume a previous session by ID                   |
| `--fork-session`  | Fork from resumed session (don't modify original) |
| `--json`          | Output raw JSON response (default: text)          |
| `--no-stream`     | Wait for complete response                        |
| `--model <model>` | Use specific model (opus, sonnet, haiku)          |
| `-p, --print`     | Print mode (suppress session ID hint)             |
| `-h, --help`      | Show help message                                 |

## Input Methods

1. **Command argument**: `claude-simple-cli "What is 2+2?"`
2. **Stdin pipe**: `echo "Explain this code" | claude-simple-cli`
3. **Interactive**: Run without arguments for prompt input

## Examples

```bash
# Simple question
claude-simple-cli "What is the capital of France?"

# Pipe input
cat error.log | claude-simple-cli "Explain this error"

# Resume a previous conversation
claude-simple-cli --resume abc123 "Can you elaborate on that?"

# Get JSON output for scripting
claude-simple-cli --json "List 3 colors" | jq '.result'

# Use specific model
claude-simple-cli --model haiku "Quick question about syntax"

# Print mode (for scripts, no hints)
claude-simple-cli -p "Generate a UUID" > output.txt
```

## Session Management

After each query, the session ID is displayed:

```
The capital of France is Paris.

Session ID: abc123def
Resume with: claude-simple-cli --resume abc123def "your message"
```

Use `--resume` to continue conversations across invocations.

## Differences from Interactive Claude

| Feature   | claude-simple-cli      | claude (interactive)   |
| --------- | ---------------------- | ---------------------- |
| Mode      | One-shot               | Persistent session     |
| State     | None (use --resume)    | In-memory              |
| Output    | Text (or JSON)         | Full TUI               |
| Streaming | Optional               | Default                |
| Best for  | Scripts, quick queries | Extended work sessions |

## Dependencies

| Tool     | Purpose                        | Installation       |
| -------- | ------------------------------ | ------------------ |
| `jq`     | JSON processing                | `brew install jq`  |
| `gum`    | Interactive prompts (optional) | `brew install gum` |
| `claude` | Claude CLI                     | Pre-installed      |
