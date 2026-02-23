# word-vomit

Claude Code plugin for capturing and processing unstructured thoughts ("word vomit") into organized, actionable work items.

## How It Works

1. **PostToolUse hook on Write/Edit**: Detects when scratch/word-vomit files are written and prompts the exec-assist agent to process them.

2. **word-vomit skill**: Provides a structured workflow for dumping thoughts and having them categorized into bugs, tasks, features, research questions, decisions, observations, reminders, or duplicates.

## Trigger Patterns

The hook fires when files matching these patterns are written:

- `.claude/scratch/word-vomit*.md`
- `.claude/scratch/thoughts*.md`
- `.claude/scratch/brain-dump*.md`
- `.claude/scratch/ideas*.md`
- Any file with `<!-- word-vomit -->` marker in the first 5 lines

## Usage

### Via Skill

Tell Claude: "I want to brain dump" or "process my word vomit" and the skill guides the workflow.

### Via File

Write thoughts to `.claude/scratch/word-vomit-2024-01-15.md` and the hook will automatically trigger processing.

### Via Marker

Add `<!-- word-vomit -->` to the top of any markdown file to mark it for processing.

## Categories

| Category | Destination | Example |
|----------|-------------|---------|
| Bug | GitHub issue + `bug` label | "auth returns 500" |
| Task | GitHub issue or TaskCreate | "update README" |
| Feature | GitHub issue + `enhancement` label | "add dark mode" |
| Research | GitHub issue + `research` label | "how does Stripe retry?" |
| Decision | Flag for user | "Redis vs Memcached?" |
| Observation | Append to doc | "deploy takes 3 min now" |
| Reminder | TaskCreate | "check CI after deploy" |
| Duplicate | Link to existing | Link if already filed |

## Companion Agent

This plugin works best with the `exec-assist` agent (`.claude/agents/exec-assist.md`) which provides comprehensive categorization and filing capabilities.

## Dependencies

- `jq` — for JSON processing
- `gh` — GitHub CLI for issue creation and deduplication
