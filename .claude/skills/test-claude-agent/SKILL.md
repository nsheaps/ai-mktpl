---
name: test-claude-agent
description: Use when testing the claude-agent workflow or needing to trigger/monitor Claude agent runs in GitHub Actions
---

# Test Claude Agent Skill

For detailed instructions on triggering and monitoring the Claude agent workflow, see:

**[docs/claude-agent-workflow.md](../../docs/claude-agent-workflow.md)**

## Quick Reference

- **Trigger**: Post `@claude <message>` on issue #102
- **Monitor**: `gh run list --workflow=claude-agent.yaml`
- **Timing**: Max 5 seconds per step
