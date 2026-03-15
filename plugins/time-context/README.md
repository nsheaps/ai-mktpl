# Time Context Plugin

Detects time-referencing language in user prompts and investigates history before answering.

## Features

### Temporal Context Investigation

When users reference time — explicitly or implicitly — this plugin ensures the agent checks history before answering. Trigger phrases include:

- "Is X now?" / "Is X still...?"
- "Has Y changed?" / "Did Y get merged?"
- "Is Z fixed yet?"
- "What happened with...?"

### Investigation Sources

The skill directs the agent to check:

- Recent git commit history
- Recent file changes
- PR/issue activity
- File modification times
- CI/CD run history

## Configuration

No configuration required. The plugin provides a skill that is auto-recalled based on trigger phrases.

## Origin

This skill was originally part of the `brain` plugin and has been extracted into its own plugin for better modularity.
