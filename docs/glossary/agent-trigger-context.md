# Agent Trigger Context

**Definition:** The information available to an AI agent at the moment of invocation that helps it understand what to do and why.

**Components:**

- **Event metadata**: What triggered the agent (PR comment, issue, cron, manual)
- **Source context**: The full content of the trigger (PR diff, issue body, commit message)
- **Environment context**: Repository state, branch, available tools
- **Historical context**: Previous interactions, related issues, conversation history

**Problem:** In GitHub Actions, agents often receive only the trigger event without surrounding context, requiring additional API calls to understand the situation.
