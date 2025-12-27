# Claude Debug Action - Usage Examples

This document provides real-world examples of using the Claude Debug Action in various scenarios.

## Table of Contents

- [Basic Usage](#basic-usage)
- [Repository Dispatch](#repository-dispatch)
- [Multi-Stage Workflows](#multi-stage-workflows)
- [External Repository Integration](#external-repository-integration)
- [Monitoring and Alerting](#monitoring-and-alerting)
- [CI/CD Integration](#cicd-integration)

---

## Basic Usage

### Simple Debug Information Extraction

```yaml
name: Claude Debug

on: [push, pull_request]

jobs:
  debug:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Get Claude Debug Info
        uses: ./.github/actions/claude-debug
        id: debug

      - name: Show Session Info
        run: |
          echo "Session: ${{ steps.debug.outputs.session-id }}"
          echo "Branch: ${{ steps.debug.outputs.git-branch }}"
```

### After Claude Code Automation

```yaml
name: Claude Automation with Debug

on:
  workflow_dispatch:
    inputs:
      task:
        description: "Task for Claude"
        required: true

jobs:
  automate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run Claude Code Task
        run: |
          # Your Claude Code automation
          claude-code --task "${{ github.event.inputs.task }}"
        env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}

      - name: Debug Claude Session
        uses: ./.github/actions/claude-debug
        id: debug
        with:
          continue: true
          extract-logs: true

      - name: Verify Success
        run: |
          if [ "${{ steps.debug.outputs.session-status }}" != "success" ]; then
            echo "Task failed: ${{ steps.debug.outputs.error }}"
            exit 1
          fi
```

---

## Repository Dispatch

### Triggering from External Repository

In your external repository, trigger the debug action:

```yaml
name: Request Debug Info

on:
  workflow_dispatch:

jobs:
  trigger-debug:
    runs-on: ubuntu-latest
    steps:
      - name: Dispatch to Debug Repository
        uses: peter-evans/repository-dispatch@v2
        with:
          token: ${{ secrets.PAT_TOKEN }}
          repository: nsheaps/.ai
          event-type: claude-debug-request
          client-payload: |
            {
              "source_repo": "${{ github.repository }}",
              "request_id": "${{ github.run_id }}",
              "issue_number": "${{ github.event.issue.number }}",
              "ref": "main",
              "continue": true,
              "extract_logs": false,
              "webhook_url": "https://api.example.com/webhooks/debug"
            }
```

### Receiving Debug Results via Webhook

```javascript
// Express.js webhook handler
app.post("/webhooks/debug", (req, res) => {
  const { request_id, source_repo, debug_info, git_context, workflow } =
    req.body;

  console.log(`Debug info received for ${source_repo}`);
  console.log(`Session ID: ${debug_info.session_id}`);
  console.log(`Status: ${debug_info.session_status}`);

  // Store in database, send notifications, etc.

  res.status(200).send("OK");
});
```

### Receiving Debug Results via PR Comment

The repository dispatch workflow automatically posts results back to the source PR:

```yaml
# In nsheaps/.ai repository (repository-dispatch-debug.yml handles this)
# External repo will receive a comment like:

## 🤖 Claude Code Debug Information

**Session ID**: `sess_abc123`
**Status**: ✅ success
**Claude Version**: `1.0.0`

### Git Context
- **Branch**: `main`
- **Commit**: `a1b2c3d`
- **Status**: `clean`
```

---

## Multi-Stage Workflows

### Sequential Claude Operations

```yaml
name: Multi-Stage Claude Workflow

on:
  workflow_dispatch:

jobs:
  multi-stage:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      # Stage 1: Code Analysis
      - name: Analyze Code
        run: |
          claude-code --task "Analyze code quality"
        env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}

      - name: Debug Stage 1
        uses: ./.github/actions/claude-debug
        id: stage1
        with:
          continue: false # New session

      # Stage 2: Fix Issues
      - name: Fix Issues
        run: |
          claude-code --continue --task "Fix issues found"
        env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}

      - name: Debug Stage 2
        uses: ./.github/actions/claude-debug
        id: stage2
        with:
          continue: true # Continue from stage 1

      # Stage 3: Verify Fixes
      - name: Verify Fixes
        run: |
          claude-code --continue --task "Verify all fixes"
        env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}

      - name: Debug Stage 3
        uses: ./.github/actions/claude-debug
        id: stage3
        with:
          continue: true

      # Validate session chain
      - name: Verify Session Continuity
        run: |
          echo "Stage 1: ${{ steps.stage1.outputs.session-id }}"
          echo "Stage 2: ${{ steps.stage2.outputs.session-id }} (prev: ${{ steps.stage2.outputs.previous-session-id }})"
          echo "Stage 3: ${{ steps.stage3.outputs.session-id }} (prev: ${{ steps.stage3.outputs.previous-session-id }})"

          # Verify chain
          if [ "${{ steps.stage2.outputs.previous-session-id }}" == "${{ steps.stage1.outputs.session-id }}" ] && \
             [ "${{ steps.stage3.outputs.previous-session-id }}" == "${{ steps.stage2.outputs.session-id }}" ]; then
            echo "✅ Session chain verified"
          else
            echo "❌ Session chain broken"
            exit 1
          fi
```

---

## External Repository Integration

### Using the Action from External Repos

In any external repository:

```yaml
name: Use Claude Debug Action

on: [push]

jobs:
  debug:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      # Reference the action from nsheaps/.ai
      - name: Debug Claude Session
        uses: nsheaps/.ai/.github/actions/claude-debug@main
        id: debug
        with:
          working-directory: .
          continue: true

      - name: Use Debug Info
        run: |
          echo "Session ID: ${{ steps.debug.outputs.session-id }}"
```

### Cross-Organization Monitoring

Monitor Claude sessions across multiple organization repositories:

```yaml
name: Org-Wide Claude Monitor

on:
  schedule:
    - cron: "0 */6 * * *" # Every 6 hours

jobs:
  monitor:
    strategy:
      matrix:
        repo:
          - org/repo1
          - org/repo2
          - org/repo3
    runs-on: ubuntu-latest
    steps:
      - name: Checkout Target Repo
        uses: actions/checkout@v4
        with:
          repository: ${{ matrix.repo }}
          token: ${{ secrets.ORG_PAT }}

      - name: Debug Claude Session
        uses: nsheaps/.ai/.github/actions/claude-debug@main
        id: debug
        continue-on-error: true

      - name: Report to Central Dashboard
        run: |
          curl -X POST https://dashboard.example.com/api/claude-sessions \
            -H "Authorization: Bearer ${{ secrets.DASHBOARD_TOKEN }}" \
            -H "Content-Type: application/json" \
            -d '{
              "repository": "${{ matrix.repo }}",
              "session_id": "${{ steps.debug.outputs.session-id }}",
              "status": "${{ steps.debug.outputs.session-status }}",
              "branch": "${{ steps.debug.outputs.git-branch }}",
              "commit": "${{ steps.debug.outputs.git-commit }}",
              "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"
            }'
```

---

## Monitoring and Alerting

### Slack Notifications

````yaml
name: Claude Debug with Slack

on: [workflow_dispatch]

jobs:
  debug-and-notify:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Debug Claude Session
        uses: ./.github/actions/claude-debug
        id: debug

      - name: Notify Slack
        uses: slackapi/slack-github-action@v1
        with:
          webhook-url: ${{ secrets.SLACK_WEBHOOK }}
          payload: |
            {
              "text": "Claude Debug Report",
              "blocks": [
                {
                  "type": "header",
                  "text": {
                    "type": "plain_text",
                    "text": "🤖 Claude Code Debug Report"
                  }
                },
                {
                  "type": "section",
                  "fields": [
                    {
                      "type": "mrkdwn",
                      "text": "*Session ID:*\n`${{ steps.debug.outputs.session-id }}`"
                    },
                    {
                      "type": "mrkdwn",
                      "text": "*Status:*\n${{ steps.debug.outputs.session-status }}"
                    },
                    {
                      "type": "mrkdwn",
                      "text": "*Branch:*\n`${{ steps.debug.outputs.git-branch }}`"
                    },
                    {
                      "type": "mrkdwn",
                      "text": "*Commit:*\n`${{ steps.debug.outputs.git-commit }}`"
                    }
                  ]
                }
              ]
            }

      - name: Alert on Error
        if: steps.debug.outputs.error != ''
        uses: slackapi/slack-github-action@v1
        with:
          webhook-url: ${{ secrets.SLACK_WEBHOOK_ALERTS }}
          payload: |
            {
              "text": "⚠️ Claude Debug Error",
              "blocks": [
                {
                  "type": "section",
                  "text": {
                    "type": "mrkdwn",
                    "text": "*Error:*\n```${{ steps.debug.outputs.error }}```"
                  }
                }
              ]
            }
````

### DataDog Metrics

```yaml
- name: Send Metrics to DataDog
  run: |
    # Send session metrics
    curl -X POST "https://api.datadoghq.com/api/v1/series" \
      -H "DD-API-KEY: ${{ secrets.DD_API_KEY }}" \
      -H "Content-Type: application/json" \
      -d '{
        "series": [
          {
            "metric": "claude.session.completed",
            "points": [["'$(date +%s)'", 1]],
            "type": "count",
            "tags": [
              "session_id:${{ steps.debug.outputs.session-id }}",
              "branch:${{ steps.debug.outputs.git-branch }}",
              "status:${{ steps.debug.outputs.session-status }}",
              "repository:${{ github.repository }}"
            ]
          },
          {
            "metric": "claude.session.count",
            "points": [["'$(date +%s)'", ${{ steps.debug.outputs.session-count }}]],
            "type": "gauge",
            "tags": [
              "repository:${{ github.repository }}"
            ]
          }
        ]
      }'
```

---

## CI/CD Integration

### Automated Testing with Debug

```yaml
name: Test with Claude Debug

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run Tests with Claude
        run: |
          # Claude helps fix failing tests
          claude-code --task "Fix failing tests"
        env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}

      - name: Debug Session
        uses: ./.github/actions/claude-debug
        id: debug

      - name: Run Tests
        id: tests
        run: npm test

      - name: Report Test Results
        if: always()
        uses: actions/github-script@v7
        with:
          script: |
            const testsPassed = '${{ steps.tests.outcome }}' === 'success';

            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: `## Test Results

              ${testsPassed ? '✅' : '❌'} Tests ${testsPassed ? 'passed' : 'failed'}

              **Claude Session**: \`${{ steps.debug.outputs.session-id }}\`
              **Branch**: \`${{ steps.debug.outputs.git-branch }}\`
              **Commit**: \`${{ steps.debug.outputs.git-commit }}\`
              `
            });
```

### Deployment with Debug Tracking

```yaml
name: Deploy with Debug Tracking

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Pre-deployment Claude Check
        run: |
          claude-code --task "Verify deployment readiness"
        env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}

      - name: Debug Pre-deployment
        uses: ./.github/actions/claude-debug
        id: pre-deploy-debug

      - name: Deploy
        id: deploy
        run: |
          # Your deployment script
          ./deploy.sh

      - name: Record Deployment
        run: |
          # Record deployment with Claude session info
          curl -X POST https://api.example.com/deployments \
            -H "Content-Type: application/json" \
            -d '{
              "commit": "${{ steps.pre-deploy-debug.outputs.git-commit }}",
              "branch": "${{ steps.pre-deploy-debug.outputs.git-branch }}",
              "claude_session": "${{ steps.pre-deploy-debug.outputs.session-id }}",
              "status": "${{ steps.deploy.outcome }}",
              "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"
            }'
```

---

## Advanced Patterns

### Conditional Debug Extraction

```yaml
- name: Debug with Conditional Log Extraction
  uses: ./.github/actions/claude-debug
  id: debug
  with:
    extract-logs: ${{ github.event_name == 'workflow_dispatch' }}

- name: Upload Logs (Manual Runs Only)
  if: github.event_name == 'workflow_dispatch'
  uses: actions/upload-artifact@v4
  with:
    name: claude-logs-${{ steps.debug.outputs.session-id }}
    path: ~/.claude/logs/
```

### Matrix Strategy with Debug

```yaml
jobs:
  test-matrix:
    strategy:
      matrix:
        os: [ubuntu-latest, macos-latest]
        node: [18, 20]
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4

      - name: Debug Environment
        uses: ./.github/actions/claude-debug
        id: debug

      - name: Tag Results
        run: |
          echo "OS: ${{ matrix.os }}"
          echo "Node: ${{ matrix.node }}"
          echo "Session: ${{ steps.debug.outputs.session-id }}"
```

---

## Troubleshooting Examples

### Debug with Verbose Output

```yaml
- name: Debug with Full Output
  uses: ./.github/actions/claude-debug
  id: debug
  with:
    additional-flags: "--verbose --debug"
    extract-logs: true

- name: Show Full JSON
  run: |
    echo '${{ steps.debug.outputs.json-output }}' | jq '.'
```

### Retry on Failure

```yaml
- name: Debug with Retry
  uses: nick-fields/retry@v2
  with:
    timeout_minutes: 5
    max_attempts: 3
    command: |
      gh workflow run .github/actions/claude-debug
```

---

For more examples, see the [main README](./README.md) and [example workflows](../../workflows/).
