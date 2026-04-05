# Claude Code Debug Action

A reusable GitHub Action for extracting debugging information from Claude Code CLI sessions. This action runs the Claude Code CLI with JSON output format to capture session metadata, git context, and diagnostic information.

## Features

- ✅ Extract current and previous session IDs
- ✅ Capture Claude Code version information
- ✅ Include git context (branch, commit, status)
- ✅ Support for continuing previous sessions
- ✅ Optional session log extraction
- ✅ Full JSON output capture
- ✅ GitHub Actions summary generation
- ✅ Works with repository dispatch workflows
- ✅ Designed for use after Claude Code automation actions

## Usage

### Basic Usage

```yaml
- name: Get Claude Code Debug Info
  uses: ./.github/actions/claude-debug
  id: debug

- name: Display Session ID
  run: echo "Session ID: ${{ steps.debug.outputs.session-id }}"
```

### With Repository Dispatch

This action is designed to work seamlessly with repository dispatch events and external repositories:

```yaml
name: External Debug Workflow

on:
  repository_dispatch:
    types: [debug-claude-session]

jobs:
  debug:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Claude Code
        run: |
          # Install Claude Code CLI
          npm install -g @anthropic/claude-code

      - name: Run Claude Debug Action
        uses: nsheaps/ai-mktpl/.github/actions/claude-debug@main
        id: debug
        with:
          continue: true
          extract-logs: true
          claude-api-key: ${{ secrets.CLAUDE_API_KEY }}

      - name: Post Results Back
        uses: peter-evans/create-or-update-comment@v3
        with:
          issue-number: ${{ github.event.client_payload.issue_number }}
          body: |
            ## Claude Code Debug Results
            - **Session ID**: `${{ steps.debug.outputs.session-id }}`
            - **Previous Session**: `${{ steps.debug.outputs.previous-session-id }}`
            - **Branch**: `${{ steps.debug.outputs.git-branch }}`
            - **Status**: `${{ steps.debug.outputs.session-status }}`
```

### After Claude Code Action

Use this action to debug or verify Claude Code automation workflows:

```yaml
- name: Run Claude Code Automation
  uses: some-org/claude-code-action@v1
  with:
    task: "Fix linting errors"
    api-key: ${{ secrets.CLAUDE_API_KEY }}

- name: Debug Claude Session
  uses: ./.github/actions/claude-debug
  id: debug
  with:
    continue: true # Continue from previous Claude session
    extract-logs: true

- name: Check for Errors
  if: steps.debug.outputs.error != ''
  run: |
    echo "Error detected: ${{ steps.debug.outputs.error }}"
    exit 1
```

### Advanced Usage with Multiple Repositories

For organizations managing multiple repositories with Claude Code:

```yaml
name: Multi-Repo Claude Debug

on:
  workflow_dispatch:
    inputs:
      target-repo:
        description: "Repository to debug"
        required: true

jobs:
  debug:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout Target Repository
        uses: actions/checkout@v4
        with:
          repository: ${{ github.event.inputs.target-repo }}
          token: ${{ secrets.ORG_PAT }}

      - name: Debug Claude Session
        uses: nsheaps/ai-mktpl/.github/actions/claude-debug@main
        id: debug
        with:
          working-directory: .
          continue: true
          extract-logs: true

      - name: Upload Debug Artifacts
        uses: actions/upload-artifact@v4
        with:
          name: claude-debug-${{ steps.debug.outputs.session-id }}
          path: |
            ${{ steps.debug.outputs.json-output }}
          retention-days: 7
```

## Inputs

| Input               | Description                                 | Required | Default |
| ------------------- | ------------------------------------------- | -------- | ------- |
| `continue`          | Whether to continue from previous session   | No       | `true`  |
| `working-directory` | Working directory for Claude Code           | No       | `.`     |
| `claude-api-key`    | Claude API key (if not in environment)      | No       | -       |
| `additional-flags`  | Additional flags to pass to claude-code CLI | No       | `''`    |
| `extract-logs`      | Whether to extract recent session logs      | No       | `false` |

## Outputs

| Output                | Description                                   |
| --------------------- | --------------------------------------------- |
| `session-id`          | Current Claude Code session ID                |
| `previous-session-id` | Previous Claude Code session ID               |
| `working-directory`   | Working directory used by Claude Code         |
| `git-branch`          | Current git branch                            |
| `git-status`          | Git status (clean/dirty)                      |
| `git-commit`          | Current git commit SHA                        |
| `session-status`      | Status of the Claude Code session             |
| `session-count`       | Number of recent sessions                     |
| `claude-version`      | Claude Code CLI version                       |
| `json-output`         | Full JSON output from claude-code CLI         |
| `error`               | Error message if command failed               |
| `logs`                | Recent session logs (if extract-logs is true) |

## Environment Requirements

This action requires:

- **Claude Code CLI**: Must be installed and available in PATH
- **jq** (optional but recommended): For detailed JSON parsing
- **git**: For extracting repository context

### Installing Claude Code CLI

```yaml
- name: Install Claude Code
  run: npm install -g @anthropic/claude-code
```

Or use a container with Claude Code pre-installed:

```yaml
jobs:
  debug:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/anthropic/claude-code:latest
```

## Use Cases

### 1. Post-Automation Debugging

After running Claude Code automation, capture session details for audit trails:

```yaml
- uses: ./.github/actions/claude-debug
  id: post-debug

- name: Save to Database
  run: |
    curl -X POST https://api.example.com/claude-sessions \
      -H "Content-Type: application/json" \
      -d '{
        "session_id": "${{ steps.post-debug.outputs.session-id }}",
        "commit": "${{ steps.post-debug.outputs.git-commit }}",
        "branch": "${{ steps.post-debug.outputs.git-branch }}"
      }'
```

### 2. Multi-Stage Workflows

Chain multiple Claude Code operations and track session continuity:

```yaml
- name: Stage 1 - Code Generation
  uses: some-org/claude-code-action@v1

- name: Debug Stage 1
  uses: ./.github/actions/claude-debug
  id: stage1-debug

- name: Stage 2 - Code Review
  uses: some-org/claude-code-action@v1
  with:
    continue-from: ${{ steps.stage1-debug.outputs.session-id }}

- name: Debug Stage 2
  uses: ./.github/actions/claude-debug
  id: stage2-debug
```

### 3. External Repository Monitoring

Monitor Claude Code sessions across organization repositories:

```yaml
name: Claude Session Monitor

on:
  schedule:
    - cron: "0 */6 * * *" # Every 6 hours

jobs:
  monitor:
    strategy:
      matrix:
        repo: [repo1, repo2, repo3]
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          repository: my-org/${{ matrix.repo }}

      - uses: nsheaps/ai-mktpl/.github/actions/claude-debug@main
        id: debug

      - name: Alert on Errors
        if: steps.debug.outputs.error != ''
        uses: slackapi/slack-github-action@v1
        with:
          payload: |
            {
              "text": "Claude error in ${{ matrix.repo }}: ${{ steps.debug.outputs.error }}"
            }
```

### 4. PR Comment Integration

Add debug information as comments on pull requests:

```yaml
- name: Debug Claude Session
  uses: ./.github/actions/claude-debug
  id: debug

- name: Comment on PR
  uses: actions/github-script@v7
  with:
    script: |
      github.rest.issues.createComment({
        issue_number: context.issue.number,
        owner: context.repo.owner,
        repo: context.repo.repo,
        body: `## 🤖 Claude Code Debug Info

        - **Session**: \`${{ steps.debug.outputs.session-id }}\`
        - **Version**: \`${{ steps.debug.outputs.claude-version }}\`
        - **Status**: ${{ steps.debug.outputs.session-status }}

        <details>
        <summary>Full JSON Output</summary>

        \`\`\`json
        ${{ steps.debug.outputs.json-output }}
        \`\`\`
        </details>`
      })
```

## Troubleshooting

### Claude Code Not Found

```yaml
# Add Claude Code installation step
- name: Install Claude Code
  run: npm install -g @anthropic/claude-code

- name: Verify Installation
  run: claude-code --version
```

### API Key Issues

Ensure the Claude API key is set:

```yaml
- uses: ./.github/actions/claude-debug
  with:
    claude-api-key: ${{ secrets.ANTHROPIC_API_KEY }}
```

Or set as environment variable:

```yaml
env:
  ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
```

### JSON Parsing Failures

Install jq for reliable JSON parsing:

```yaml
- name: Install jq
  run: sudo apt-get update && sudo apt-get install -y jq
```

### Output Too Large

The action automatically truncates outputs larger than 65KB. For full logs, use the artifact upload feature:

```yaml
- uses: ./.github/actions/claude-debug
  with:
    extract-logs: true

- uses: actions/upload-artifact@v4
  with:
    name: claude-logs
    path: ~/.claude/logs/
```

## Security Considerations

### API Key Handling

- Always use GitHub Secrets for API keys
- Never commit API keys in workflow files
- Use environment-specific secrets for different deployments

### Repository Dispatch

When using with repository dispatch:

- Validate webhook signatures
- Use repository dispatch types for access control
- Limit which repositories can trigger workflows

```yaml
on:
  repository_dispatch:
    types: [debug-claude-session] # Specific type for access control

jobs:
  debug:
    # Only allow from trusted repositories
    if: github.event.client_payload.source_repo == 'trusted-org/trusted-repo'
```

### Log Extraction

Be cautious when extracting logs with `extract-logs: true`:

- Logs may contain sensitive information
- Review logs before posting in public comments
- Use private artifacts for sensitive debug data

## Integration Examples

### With Slack Notifications

```yaml
- uses: ./.github/actions/claude-debug
  id: debug

- uses: slackapi/slack-github-action@v1
  with:
    webhook-url: ${{ secrets.SLACK_WEBHOOK }}
    payload: |
      {
        "text": "Claude Session Complete",
        "blocks": [
          {
            "type": "section",
            "text": {
              "type": "mrkdwn",
              "text": "*Session ID*: `${{ steps.debug.outputs.session-id }}`\n*Branch*: `${{ steps.debug.outputs.git-branch }}`\n*Status*: ${{ steps.debug.outputs.session-status }}"
            }
          }
        ]
      }
```

### With DataDog Metrics

```yaml
- uses: ./.github/actions/claude-debug
  id: debug

- name: Send to DataDog
  run: |
    curl -X POST "https://api.datadoghq.com/api/v1/series" \
      -H "DD-API-KEY: ${{ secrets.DD_API_KEY }}" \
      -d '{
        "series": [{
          "metric": "claude.session.complete",
          "points": [['$(date +%s)', 1]],
          "tags": [
            "session_id:${{ steps.debug.outputs.session-id }}",
            "branch:${{ steps.debug.outputs.git-branch }}",
            "status:${{ steps.debug.outputs.session-status }}"
          ]
        }]
      }'
```

## Contributing

Contributions welcome! Please:

1. Test changes locally with `act` or GitHub Actions
2. Update documentation for new inputs/outputs
3. Add examples for new use cases
4. Follow existing code style

## Support

- **Issues**: [GitHub Issues](https://github.com/nsheaps/ai-mktpl/issues)
- **Discussions**: [GitHub Discussions](https://github.com/nsheaps/ai-mktpl/discussions)
- **Claude Code Docs**: [code.claude.com/docs](https://code.claude.com/docs)

## Related Actions

- [Claude Code Action](https://github.com/anthropics/claude-code-action) - Main Claude Code automation action
- [Setup Claude Code](https://github.com/anthropics/setup-claude-code) - Install Claude Code CLI

---

**Part of the [Claude Code Plugin Marketplace](https://github.com/nsheaps/ai-mktpl)**
