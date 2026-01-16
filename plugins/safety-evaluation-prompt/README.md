# Safety Evaluation Plugin (Prompt Style)

An AI-powered pre-tool-call safety evaluation plugin for Claude Code that uses prompt-style hooks for inline security assessment.

## How It Works

This plugin installs a **prompt-style hook** that provides Claude with safety evaluation instructions before every tool call. Unlike the script-style variant, this approach:

1. Injects a safety evaluation prompt into Claude's context
2. Claude internally evaluates the tool call against security criteria
3. Claude either proceeds, blocks, or asks the user for confirmation
4. No external CLI calls - evaluation happens inline

## Features

- **Zero Latency Overhead**: No external process calls
- **Context-Aware**: Claude has full conversation context for better decisions
- **Interactive**: Can ask users for confirmation on ambiguous operations
- **Simple Setup**: No scripts to install or configure
- **Self-Documenting**: The prompt explains exactly what's being checked

## Installation

See [Installation Guide](../../docs/installation.md) for all installation methods.

### Quick Install

```bash
# Via marketplace (recommended)
# Follow marketplace setup: ../../docs/manual-installation.md

# Or via GitHub
claude plugins install github:nsheaps/.ai/plugins/safety-evaluation-prompt

# Or locally for testing
cc --plugin-dir /path/to/plugins/safety-evaluation-prompt
```

## Safety Evaluation Criteria

The prompt instructs Claude to evaluate tool calls against these security criteria:

1. **Destructive Operations**: File/system deletion or modification
2. **Data Exfiltration**: Credential or sensitive data leakage
3. **Network Security**: Suspicious network calls or service exposure
4. **Privilege Escalation**: Attempts to gain elevated permissions
5. **Code Injection**: Arbitrary or malicious code execution
6. **Resource Abuse**: Fork bombs, infinite loops, excessive resource use

## Decision Guidelines

The plugin uses this decision framework:

| Operation Type                                   | Decision     |
| ------------------------------------------------ | ------------ |
| Normal development (git, npm, file editing)      | **ALLOW**    |
| Read-only operations (cat, ls, grep)             | **ALLOW**    |
| Obviously dangerous (rm -rf /, credential theft) | **BLOCK**    |
| Ambiguous/risky                                  | **ASK USER** |

## Comparison with Script-Style Hooks

| Aspect        | Prompt Style (This Plugin) | Script Style                   |
| ------------- | -------------------------- | ------------------------------ |
| Execution     | Inline Claude evaluation   | External script process        |
| Latency       | Lower (no external calls)  | Higher (separate CLI call)     |
| Context       | Full conversation context  | Limited to tool call only      |
| Flexibility   | Natural language only      | Full programming capabilities  |
| Customization | Edit the prompt text       | Environment variables, logging |
| Determinism   | Context-dependent          | More deterministic             |

## When to Use This Plugin

Choose the **prompt-style** plugin when:

- You want minimal latency overhead
- Context-aware evaluation is important
- You prefer interactive confirmation over hard blocks
- You don't need detailed audit logging
- Simplicity is preferred over configurability

Choose the **script-style** plugin when:

- You need detailed audit logging
- You want deterministic, consistent evaluation
- You need to integrate with external systems
- You prefer hard blocks over interactive prompts
- You want to use a specific model (like Haiku) for evaluation

## Customization

To customize the safety evaluation criteria, edit the `prompt` field in the plugin.json file. The prompt uses natural language, so you can:

- Add or remove evaluation criteria
- Adjust the decision thresholds
- Change the communication style
- Add domain-specific security rules

### Example: Adding Custom Rules

```json
{
  "type": "prompt",
  "prompt": "SAFETY EVALUATION: ... [existing prompt] ...\n\nADDITIONAL RULES FOR THIS PROJECT:\n- Never allow commands that access the /production directory\n- Always ask before running database migrations\n- Block any npm publish commands"
}
```

## Limitations

- Less deterministic than script-based evaluation
- No audit trail without additional configuration
- Cannot integrate with external security systems
- Evaluation quality depends on Claude's judgment
- May slow down rapid tool call sequences due to evaluation overhead

## Troubleshooting

### Claude is being too restrictive

Edit the prompt to be more permissive for your use case, or add specific exceptions for common operations in your workflow.

### Claude isn't catching dangerous operations

Strengthen the prompt with more specific examples of operations that should be blocked in your environment.

### Want both approaches?

You can use both plugins together! The script-style hook will run first (providing hard blocks), and the prompt-style will add an additional layer of context-aware evaluation.

## License

MIT License - See the main repository for details.
