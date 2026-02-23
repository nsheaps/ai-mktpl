---
name: word-vomit
description: |
  Use when the user wants to dump unstructured thoughts, ideas, or notes that need to be organized.
  Triggers: "brain dump", "word vomit", "let me think out loud", "process my notes", "organize my thoughts", "dump my ideas".
---

# Word Vomit Workflow

Process unstructured user thoughts into organized, actionable items.

## Quick Start

1. User writes thoughts to a scratch file or sends them as a message
2. This skill guides you through categorization and filing

## Workflow

### Step 1: Capture

If the user hasn't already written their thoughts to a file, save them to:
```
.claude/scratch/word-vomit-<date>.md
```

Add the marker at the top of the file:
```markdown
<!-- word-vomit -->
# Brain Dump — <date>

- thought 1
- thought 2
...
```

### Step 2: Process

For each item in the file:

1. **Parse**: Split into discrete thoughts (one per bullet or paragraph)
2. **Categorize** using this table:

| Category | Destination | Labels |
|----------|-------------|--------|
| Bug | GitHub issue | `bug` |
| Task | GitHub issue or TaskCreate | none |
| Feature idea | GitHub issue | `enhancement` |
| Research question | GitHub issue | `research` |
| Decision needed | Present to user with options | none |
| Observation/note | Append to relevant doc | none |
| Reminder | TaskCreate with context | none |
| Duplicate | Link to existing issue | none |

3. **Deduplicate**: Search existing issues with `gh issue list` before creating new ones
4. **File**: Create issues, tasks, or doc entries as appropriate

### Step 3: Update Source

After filing each item, update the original file:

```markdown
# Before
- fix the auth endpoint returning 500

# After
- ~~fix the auth endpoint returning 500~~ → [nsheaps/agent-team#42](https://github.com/nsheaps/agent-team/issues/42)
```

Rules:
- Strikethrough original text with `~~text~~`
- Add link to filed item
- Never delete original text
- If input was a message (not file), include mapping in summary

### Step 4: Summarize

Provide a structured summary:

```markdown
## Processed Items

| # | Original | Category | Filed As | Priority |
|---|----------|----------|----------|----------|
| 1 | "fix auth 500" | Bug | nsheaps/repo#42 | p1 |
| 2 | "add dark mode" | Feature | nsheaps/repo#43 | p3 |

## Decisions Needed
- Redis vs Memcached — need user input on requirements
```

## Quality Standards

- **Zero drops**: Every item must appear in the output
- **No fabrication**: Never invent details
- **Deduplication**: Always check for existing issues first
- **Traceability**: Every filed item links back to original thought
- **Correct routing**: Items go to the right repo with the right labels

## Tips

- For large dumps (15+ items), process in batches
- If an item spans multiple categories, split it
- Vague items get filed with `needs-clarification` label
- Default ambiguous items to "Task" category
