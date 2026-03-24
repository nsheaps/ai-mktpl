---
name: parallel-review
description: >
  Run a parallel multi-agent code review using Claude Code Agent Teams.
  Triggers on "parallel review", "team review", "agent team review",
  "fan-out review", "swarm review", or when a comprehensive review with
  maximum parallelism is needed. Requires agent teams to be enabled.
argument-hint: [PR number | PR URL | branch name]
---

# Parallel Review — Agent Teams Fan-Out

A parallel code review workflow that uses Claude Code's Agent Teams feature to fan out review responsibilities across multiple concurrent teammates. Each teammate specializes in one review dimension, working independently and simultaneously for faster, more thorough reviews.

## Prerequisites

Agent Teams must be enabled:
```bash
export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1
```

Or in settings.json:
```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

For visual monitoring, use tmux mode:
```bash
claude --teammate-mode tmux
```

## Architecture

```
Lead Agent (Orchestrator)
  │
  ├─ Creates team: "pr-review-<PR_NUMBER>"
  │
  ├─ Creates tasks (one per review dimension)
  │
  ├─ Spawns 8 teammates (one per dimension):
  │   ├─ simplicity-reviewer (model: sonnet)
  │   ├─ flexibility-reviewer (model: sonnet)
  │   ├─ usability-reviewer (model: sonnet)
  │   ├─ documentation-reviewer (model: sonnet)
  │   ├─ security-reviewer (model: sonnet)
  │   ├─ patterns-reviewer (model: sonnet)
  │   ├─ best-practices-reviewer (model: sonnet)
  │   └─ qa-reviewer (model: sonnet)
  │
  ├─ Teammates work independently:
  │   ├─ Read PR diff, files, context
  │   ├─ Evaluate their dimension (score 0-100)
  │   ├─ Write REPORT.md to shared location
  │   ├─ Leave inline PR comments (optional)
  │   └─ Mark task complete
  │
  ├─ Lead synthesizes all reports
  │   ├─ Cross-reference findings
  │   ├─ Build score table
  │   ├─ Draft final review
  │   └─ Post review to PR
  │
  └─ Clean up team
```

## Review Dimensions

Same as the self-review skill:

| Dimension | Teammate Name | Focus |
|-----------|--------------|-------|
| Simplicity | `simplicity-reviewer` | KISS, YAGNI, unnecessary complexity |
| Flexibility | `flexibility-reviewer` | Open/Closed, extensibility |
| Usability | `usability-reviewer` | API ergonomics, DX, discoverability |
| Documentation | `documentation-reviewer` | Comments, docs, PR description accuracy |
| Security | `security-reviewer` | Auth, input validation, secrets, OWASP |
| Patterns | `patterns-reviewer` | Repo pattern adherence, new pattern quality |
| Best Practices | `best-practices-reviewer` | SOLID, DRY, TDA, error handling |
| QA/Engineering | `qa-reviewer` | Test coverage, edge cases, reliability |

## How to Use

### Interactive (from CLI)

```
Create an agent team to review PR #42. Spawn 8 reviewers, one for each
quality dimension. Use Sonnet for each reviewer. Have them each write a
REPORT.md and leave inline comments. When they're done, synthesize their
findings into a final review.
```

### Programmatic (from a skill/prompt)

The lead should:

1. **Create the team:**
   ```
   TeamCreate: name="pr-review-42", description="Parallel review of PR #42"
   ```

2. **Create tasks** for each dimension with the PR context in the description.

3. **Spawn teammates** with descriptive names and focused prompts. Each prompt should include:
   - The PR number and repo
   - Which dimension to focus on
   - Where to write the report
   - The review criteria (from self-review skill)

4. **Enter delegate mode** (Shift+Tab) so the lead doesn't implement anything itself.

5. **Wait for all teammates** to complete and mark tasks done.

6. **Synthesize** by reading all REPORT.md files and creating the final review.

## Report Storage

Each teammate writes to:
```
.claude/pr-reviews/<org>/<repo>/<pr_number>/<epoch_timestamp>/<dimension>/REPORT.md
```

The lead writes the synthesized report to:
```
.claude/pr-reviews/<org>/<repo>/<pr_number>/<epoch_timestamp>/FINAL-REVIEW.md
```

## When to Use This vs. Self-Review

| Scenario | Use |
|----------|-----|
| Quick review, small PR | `self-review` (sub-agents) |
| Large PR, complex changes | `parallel-review` (agent teams) |
| CI automated review | `self-review` (CI doesn't support agent teams) |
| Interactive deep review | `parallel-review` |
| Cost-sensitive | `self-review` (~440k tokens vs ~800k+ for teams) |

## Token Cost Considerations

Agent teams use significantly more tokens than sub-agents:
- Sub-agent review (~8 agents): ~440k tokens
- Agent team review (~8 teammates): ~800k-1.2M tokens

The extra cost buys:
- True parallelism (teammates run simultaneously)
- Cross-referencing between reviewers (teammates can message each other)
- Ability to challenge findings (adversarial review)
- Visual monitoring via tmux split panes

## Relationship to CI Review Bot

The CI review bot (`.github/workflows/claude-code-review.yaml`) runs a single-agent review using the prompt template. It uses `self-review` style sub-agents for parallelism within that single session.

The `parallel-review` skill is designed for interactive use where the user has agent teams enabled and wants maximum review depth. A future version of the CI workflow could adopt this pattern by running the lead agent with `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`.

## Best Practices

1. **Use meaningful teammate names** — `security-reviewer` not `worker-1`
2. **Use Sonnet for teammates** — cost-efficient for focused tasks
3. **Keep the lead in delegate mode** — prevents the lead from doing review work itself
4. **Pre-approve common operations** — configure permissions before spawning to reduce interruptions
5. **Set a consistent epoch timestamp** — pass the same timestamp to all teammates so reports are grouped
6. **Avoid file conflicts** — each teammate writes only to its own `<dimension>/` directory
