# braintrust

Configure [Braintrust](https://braintrust.dev) AI evaluation and observability for Claude Code sessions.

## What is Braintrust?

Braintrust is an AI evaluation, tracing, and observability platform. It lets you:

- Log and trace AI model calls (prompts, completions, tool use)
- Run structured evaluations (evals) against datasets
- Monitor production AI applications
- Compare model outputs across experiments

## Required Environment Variables

| Variable             | Description                    | How to get it                                                                 |
| -------------------- | ------------------------------ | ----------------------------------------------------------------------------- |
| `BRAINTRUST_API_KEY` | API key for Braintrust tracing | [braintrust.dev/app/settings](https://braintrust.dev/app/settings) → API keys |

## Setup

This plugin does not install anything on its own. The `BRAINTRUST_API_KEY` environment variable must be set for Braintrust integrations to work.

### Recommended: Use the 1pass plugin to inject the API key

Configure the `1pass` plugin to read the key from 1Password and inject it at session start:

```yaml
# .claude/plugins.settings.yaml
1pass:
  enabled: true
  secrets:
    - envVar: BRAINTRUST_API_KEY
      reference: "op://YourVault/Braintrust/api-key"
      target: envFile
```

### Manual setup

Set the environment variable in your shell profile or `.claude/settings.json`:

```json
{
  "env": {
    "BRAINTRUST_API_KEY": "your-key-here"
  }
}
```

> **Note:** Avoid committing API keys to your repo. Use `settings.local.json` or the 1pass plugin.

## Usage

Once `BRAINTRUST_API_KEY` is set, Braintrust SDKs will automatically pick it up:

```python
# Python
import braintrust
braintrust.login()

# or via autologin (reads BRAINTRUST_API_KEY automatically)
from braintrust import traced
```

```typescript
// TypeScript
import { initLogger } from "braintrust";
initLogger({ projectName: "my-project" });
```

## SDK Installation

Install the Braintrust SDK for your language:

```bash
# Python
pip install braintrust

# Node.js / TypeScript
npm install braintrust
```

## Resources

- [Braintrust Docs](https://braintrust.dev/docs)
- [Python SDK](https://braintrust.dev/docs/libs/python)
- [Node.js SDK](https://braintrust.dev/docs/libs/node)
- [Running Evals](https://braintrust.dev/docs/guides/evals)
