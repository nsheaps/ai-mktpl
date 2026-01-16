# Claude Agent Workflow

Documentation for triggering and monitoring the Claude agent workflow in GitHub Actions.

## How It Works

The Claude agent runs in two stages:

1. **Trigger Workflow** (`.github/workflows/claude-agent-trigger.yaml`)
   - Listens for @claude mentions in issues, PRs, and comments
   - Creates a repository_dispatch event with context payload

2. **Agent Workflow** (`.github/workflows/claude-agent.yaml`)
   - Receives the repository_dispatch event
   - Runs Claude Code in agent mode with the provided prompt
   - Responds using GitHub MCP tools

## Triggering the Workflow

### Post a Comment with @claude

Comment on any issue or PR with `@claude` followed by your request:

```
@claude please review this implementation
```

The trigger workflow detects the mention and dispatches to the agent.

### Testing with Issue #102

For testing workflow changes, use issue #102:

```bash
# Post a test comment
gh issue comment 102 --body "@claude test the workflow"

# Or repeat the last comment pattern
gh issue view 102 --json comments --jq '.comments[-1].body' | \
  gh issue comment 102 --body-file -
```

## Monitoring the Workflow

### Check Recent Runs

```bash
# List recent claude-agent runs
gh run list --workflow=claude-agent.yaml --limit 5

# View specific run details
gh run view <run-id>
```

### Timing Expectations

**Maximum 5 seconds per step** when monitoring workflow progress:

```bash
# Check status every 5 seconds
while true; do
  gh run list --workflow=claude-agent.yaml --limit 1
  sleep 5
done
```

### View Live Output

```bash
# Watch a specific run
gh run watch <run-id>
```

## Workflow Configuration

**Triggers**: `repository_dispatch` with type `claude-agent`

**Key Inputs**:

- `bot_id: '41898282'` - Claude's GitHub user ID
- `bot_name: 'claude[bot]'` - Claude's GitHub username
- Prompt extracted from comment/issue body

**Git Configuration**:
Claude runs with bot identity configured, allowing it to make commits with proper user.name and user.email.

## Troubleshooting

### Workflow Not Triggering

Check if the trigger workflow ran:

```bash
gh run list --workflow=claude-agent-trigger.yaml --limit 5
```

The trigger workflow must succeed for the agent workflow to dispatch.

### Agent Workflow Fails

1. Check workflow syntax is valid (CI should validate this)
2. Verify secrets are configured (ANTHROPIC_API_KEY or CLAUDE_CODE_OAUTH_TOKEN)
3. Check that bot_id and bot_name are set correctly

## References

- Trigger Workflow: `.github/workflows/claude-agent-trigger.yaml`
- Agent Workflow: `.github/workflows/claude-agent.yaml`
- Payload Schema: `.github/schemas/claude-agent-payload.schema.json`
