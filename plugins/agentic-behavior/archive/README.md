# agentic-behavior Archive

This directory holds versioned snapshots of the `agentic-behavior` plugin's ruleset,
produced by the `ruleset-evolution` skill on each iteration.

## Directory Structure

Each subdirectory is named with a UTC ISO-8601 timestamp (filesystem-safe format):

```
archive/
  YYYY-MM-DDTHHMMSSZ/        ← one directory per skill run
    manifest.yaml             ← list of every captured file + git hash at capture time
    evaluation.md             ← rubric scores for the prior ruleset with citations
    new-ruleset-diff.md       ← description of what changed in rules/ and skills/
    cross-plugin-todos.md     ← gaps attributable to other plugins (do not act on here)
    rules/                    ← snapshot of plugins/agentic-behavior/rules/ at capture time
    skills/                   ← snapshot of plugins/agentic-behavior/skills/ at capture time
    hooks/                    ← snapshot of plugins/agentic-behavior/hooks/scripts/ at capture time
    rubric/                   ← snapshot of plugins/agentic-behavior/rubric/ at capture time
  README.md                   ← this file
  .gitkeep                    ← ensures the archive/ dir itself is tracked before any runs
```

## File Descriptions

### manifest.yaml

Records every file captured in the snapshot with its git hash at capture time.

```yaml
captured_at: 2026-05-24T143022Z
iteration: 1
plugin_version_hash: abc1234   # git hash of HEAD at capture time
agents_using_plugin:
  - alex
  - jack
  - henry
files:
  - path: rules/autonomy.md
    git_hash: abc1234
  - path: skills/correct-behavior/SKILL.md
    git_hash: def5678
  # ... one entry per captured file
```

### evaluation.md

Rubric scores for the ruleset at this snapshot. Produced BEFORE any changes are made
to the live ruleset. Format:

```
# Evaluation — Iteration N (YYYY-MM-DDTHHMMSSZ)

## Category: <Name> — Score: N/5

**Definition:** <from rubric>

**Evidence:**
- <citation 1: file path or journal/memory entry>
- <citation 2>

**Reasoning:** <why this score, not higher or lower>

**Status:** ESCALATED | new | improving | resolved
(ESCALATED = same category scored ≤ 3 in previous iteration AND this one)
```

### new-ruleset-diff.md

A plain-language description of every change made to `rules/` and `skills/` in this
iteration. Supplements the git diff and explains the reasoning behind each change.

### cross-plugin-todos.md

Gaps in agent behavior identified during evaluation that belong to a different plugin
(e.g., common-sense, scm-utils). Captured here for trend tracking but NOT acted on in
this run. Format:

```
## Cross-Plugin TODOs — Iteration N

| Gap | Likely Plugin | Priority | First Seen |
|-----|--------------|----------|------------|
| ... | common-sense | p2       | iter-1     |
```

## Retention Policy

Archive directories are permanent — do not delete them. They provide trend data for
rubric scoring (detecting when the same issues recur across iterations) and serve as
an audit trail for ruleset evolution. If storage becomes a concern, compress the
`rules/` and `skills/` snapshots but keep `evaluation.md` and `manifest.yaml`.

## Related

- `rubric/RUBRIC.md` — the current scoring rubric
- `skills/ruleset-evolution/SKILL.md` — the skill that creates these snapshots
