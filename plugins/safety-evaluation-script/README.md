# Safety Evaluation Plugin (Script Style)

An AI-powered pre-tool-call safety evaluation plugin for Claude Code that uses the Claude CLI with Haiku to analyze tool calls before execution.

## How It Works

This plugin installs a **script-style hook** that intercepts all tool calls before they execute. The hook:

1. Receives the tool call details (tool name and input parameters)
2. Skips evaluation for safe read-only tools (read, glob, grep, websearch)
3. Calls the Claude CLI with the Haiku model to evaluate potentially risky operations
4. Returns `allow` or `block` based on the AI's safety assessment

## Features

- **AI-Powered Evaluation**: Uses Claude Haiku for fast, intelligent safety analysis
- **Configurable Model**: Override the model via `SAFETY_EVAL_MODEL` environment variable
- **Timeout Protection**: Configurable timeout prevents hanging (default: 30s)
- **Optional Logging**: Enable audit logs via `SAFETY_EVAL_LOG` environment variable
- **Performance Optimized**: Automatically skips evaluation for known-safe read-only tools

## Installation

1. Copy this plugin to your Claude Code plugins directory
2. Ensure the hook script is executable:
   ```bash
   chmod +x hooks/pre-tool-safety-check.sh
   ```
3. Ensure you have the Claude CLI installed and authenticated

## Configuration

### Environment Variables

| Variable              | Default                   | Description                        |
| --------------------- | ------------------------- | ---------------------------------- |
| `SAFETY_EVAL_MODEL`   | `claude-3-5-haiku-latest` | Model to use for safety evaluation |
| `SAFETY_EVAL_TIMEOUT` | `30`                      | Timeout in seconds for evaluation  |
| `SAFETY_EVAL_LOG`     | (none)                    | Path to log file for audit trail   |

### Example: Enable Logging

```bash
export SAFETY_EVAL_LOG=~/.claude/safety-audit.log
```

## Safety Evaluation Criteria

The AI evaluates tool calls against these security criteria:

1. **Destructive Operations**: File/system deletion or modification
2. **Data Exfiltration**: Credential or sensitive data leakage
3. **Network Security**: Suspicious network calls or service exposure
4. **Privilege Escalation**: Attempts to gain elevated permissions
5. **Code Injection**: Arbitrary or malicious code execution
6. **Resource Abuse**: Fork bombs, infinite loops, excessive resource use

## Risk Levels

The evaluator assigns one of four risk levels:

- **low**: Normal development operations
- **medium**: Operations that warrant attention but are likely safe
- **high**: Potentially dangerous operations requiring scrutiny
- **critical**: Operations that should be blocked

## Hook Response Format

The hook returns JSON in this format:

```json
// Allow the operation
{"decision": "allow"}

// Block the operation
{
  "decision": "block",
  "reason": "Safety evaluation blocked this operation: [reason] (Risk level: [level])"
}
```

## Comparison with Prompt-Style Hooks

| Aspect        | Script Style (This Plugin)     | Prompt Style              |
| ------------- | ------------------------------ | ------------------------- |
| Execution     | External script process        | Inline Claude evaluation  |
| Latency       | Higher (separate CLI call)     | Lower (inline processing) |
| Flexibility   | Full programming capabilities  | Natural language only     |
| Customization | Environment variables, logging | Prompt text only          |
| Determinism   | More deterministic             | Context-dependent         |

## Limitations

- Requires Claude CLI to be installed and authenticated
- Adds latency to tool calls (especially for the first call)
- May occasionally block legitimate operations (false positives)
- Network connectivity required for AI evaluation

## Troubleshooting

### Hook times out frequently

Increase the timeout:

```bash
export SAFETY_EVAL_TIMEOUT=60
```

### Too many false positives

Consider using the prompt-style variant which has more context about the conversation, or adjust the system prompt in the script.

### Evaluation failures

Check that:

1. Claude CLI is installed: `which claude`
2. CLI is authenticated: `claude --version`
3. Network connectivity is available

## License

MIT License - See the main repository for details.
