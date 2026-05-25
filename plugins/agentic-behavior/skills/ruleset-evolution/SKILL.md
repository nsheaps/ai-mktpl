---
name: ruleset-evolution
description: >-
  Dream cycle for the agentic-behavior plugin's ruleset. Snapshots the current
  ruleset, scores it against a versioned rubric, rewrites the lowest-scoring
  areas, and emits a dreaming-style journal entry with priorities for the next
  iteration. Run periodically (monthly cadence suggested) or after a cluster of
  behavioral incidents. Always scores BEFORE rewriting.
context: fork
model: sonnet
allowed-tools: >-
  Read, Glob, Grep, Write, Edit, Bash(mkdir:*), Bash(ls:*), Bash(find:*),
  Bash(cp:*), Bash(date:*), Bash(wc:*), Bash(printf:*), Bash(git log:*),
  Bash(git diff:*), Bash(git status:*), Bash(git rev-parse:*), Bash(git add:*),
  Bash(git commit:*), Bash(git push:*), Bash(git checkout:*),
  Bash(git branch:*), Bash(gh pr:*), Bash(gh label:*)
---

<!-- UPSTREAM: agentic-behavior (this file IS the upstream — it lives in the plugin it governs) -->

# ruleset-evolution

Iterative self-improvement for the `agentic-behavior` plugin's ruleset. This is the
plugin's own **dream cycle**: the same way an agent dreams to consolidate learning
and surface improvements between work sessions, this skill is how the plugin
consolidates the behavioral evidence collected during its previous lifecycle and
emits a refined ruleset for the next one.

Runs in a forked context (`context: fork`) so the caller's session is not polluted
by the evaluation, evidence-gathering, and rewrite work — the caller gets a clean
final report.

## Relation to the dreaming framework

The dreaming framework (see `~/src/nsheaps/agents/docs/journal/` and the
`writing-journal-entries` skill) distinguishes:

- **Dream alone** — an agent reflecting on its own recent history.
- **Dream together (unimatrix-zero)** — multiple agents iteratively challenging each other's views.
- **Day-dreaming** — async reflection on a scheduled cron with optional random firing.

This skill is the **dream-alone** variant for a plugin (rather than an agent):
the `agentic-behavior` plugin reflects on its own observed behavioral output
(the running agents' actions are its "experience"), scores that output against
its rubric, and dreams a refined ruleset. The journal entry it produces is a
genuine dream artifact, not a status report.

## When to Use

- Periodically (monthly cadence suggested), or after a cluster of behavioral incidents.
- After the handler says "the rules aren't working" or "behavior has drifted."
- After an `ESCALATED` category appears in two consecutive evaluation reports.
- When onboarding a new agent and wanting to calibrate the plugin's rules to observed behavior.
- As part of a broader agent dream cycle that includes plugin-level reflection.

## What This Skill Does NOT Do

- Does NOT modify plugins other than `agentic-behavior` (cross-plugin gaps are noted, not fixed).
- Does NOT delete archive directories — they are permanent.
- Does NOT run automatically — it must be explicitly invoked.
- Does NOT evaluate rules that were changed in the SAME run — only the snapshot is evaluated.

---

## Steps

### Step 1: Orient — Determine Iteration Number and Timestamp

```bash
# Count existing archive snapshots (excludes README and .gitkeep)
N=$(ls plugins/agentic-behavior/archive/ \
  | grep -vE '^(README\.md|\.gitkeep)$' \
  | wc -l | tr -d ' ')
ITER=$((N + 1))

# Filesystem-safe UTC timestamp (no colons)
TS=$(date -u '+%Y-%m-%dT%H%M%SZ')

echo "Starting dream cycle iteration $ITER at $TS"
```

Set `ITER` and `TS` as mental variables — you will use them throughout all
remaining steps.

### Step 2: Snapshot the Current Ruleset

Create the archive directory and copy everything into it BEFORE making any changes
to live files. The snapshot is what you score against; the live files are what you
rewrite afterwards.

```bash
SNAPSHOT_DIR="plugins/agentic-behavior/archive/$TS"
mkdir -p "$SNAPSHOT_DIR/rules"
mkdir -p "$SNAPSHOT_DIR/skills"
mkdir -p "$SNAPSHOT_DIR/hooks"
mkdir -p "$SNAPSHOT_DIR/rubric"

# Copy rule files
cp -r plugins/agentic-behavior/rules/. "$SNAPSHOT_DIR/rules/"

# Copy skill files (including subdirectories and SKILL.md files)
cp -r plugins/agentic-behavior/skills/. "$SNAPSHOT_DIR/skills/"

# Copy hook scripts (governance tools — these constitute the enforcement layer)
cp -r plugins/agentic-behavior/hooks/scripts/. "$SNAPSHOT_DIR/hooks/" 2>/dev/null || true

# Copy current rubric (the one being used THIS iteration)
cp -r plugins/agentic-behavior/rubric/. "$SNAPSHOT_DIR/rubric/"
```

#### Discover which agents use this plugin

Check each agent's plugin configuration:

```bash
for agent_dir in ~/.agents/*/; do
  agent=$(basename "$agent_dir")
  if grep -r "agentic-behavior" "$agent_dir" --include="*.yaml" -l 2>/dev/null | head -1 | grep -q .; then
    echo "  - $agent"
  fi
done
```

#### Write manifest.yaml

Create `$SNAPSHOT_DIR/manifest.yaml` with this structure:

```yaml
captured_at: <TS>
iteration: <ITER>
plugin_version_hash: <output of: git rev-parse HEAD>
agents_using_plugin:
  - <name of each agent discovered above>
files:
  - path: rules/<filename>
    git_hash: <output of: git rev-parse HEAD:plugins/agentic-behavior/rules/<filename>>
  # repeat for each captured file
```

Use `git rev-parse HEAD:<relative-path>` to get the blob hash for each file. If a
file is untracked (new, not yet committed), note `git_hash: untracked`.

### Step 3: Read the Current Rubric

Read `plugins/agentic-behavior/rubric/RUBRIC.md` to identify the categories for this
iteration. The rubric in the SNAPSHOT is the authoritative one for this evaluation —
use it, do not modify it during scoring.

Note the category names. You will produce one scored section per category.

### Step 4: Gather Evidence for Each Category

For each rubric category, collect behavioral evidence from:

1. **`memory/` directory** in the running agent's repo (typically
   `~/src/nsheaps/.ai-agent-<name>/memory/*.md`). Look for incident records,
   behavioral notes, handler corrections.

2. **`docs/journal/`** in the agents monorepo (typically
   `~/src/nsheaps/agents/docs/journal/`). Look for entries referencing behavioral
   failures, corrections, or patterns — including prior dream entries.

3. **Comments within the rules files themselves.** Many rules cite the incident or
   handler message that motivated them (e.g., `<!-- handler feedback #46 -->`).

4. **Prior evaluation files.** Check `plugins/agentic-behavior/archive/*/evaluation.md`
   for the most recent prior iteration's scores. If the same category scored ≤ 3 in
   the prior iteration AND scores ≤ 3 in this one, mark it **ESCALATED**.

Collect 2–4 concrete citations per category. Vague assertions ("the agent sometimes
does X") are not useful for trend analysis — cite a specific file, journal entry, or
incident date.

### Step 5: Score and Write evaluation.md

Write `$SNAPSHOT_DIR/evaluation.md` with one scored section per rubric category.
Score BEFORE forming any opinion about what to change. This is the dream's
**recall phase** — you're observing what happened, not deciding what to do about it.

Format each section:

```markdown
## Category: <Name> — Score: <N>/5

**Definition:** <copied from rubric>

**Evidence:**

- <citation 1: specific file path, journal date, or incident>
- <citation 2>
- <citation 3 if available>

**Reasoning:** <why this score and not one higher or lower>

**Status:** new | improving | stagnant | ESCALATED
```

Status rules:

- `new` — first time this category is evaluated (no prior archive).
- `improving` — this iteration's score is higher than the prior iteration's score.
- `stagnant` — same score as prior iteration (positive or neutral).
- `ESCALATED` — scored ≤ 3 in the prior iteration AND ≤ 3 in this one. Use this
  status even if the score numerically improved (e.g., 2 → 3 is still ESCALATED if
  both are ≤ 3).

End `evaluation.md` with a summary table:

```markdown
## Summary

| Category               | Score | Status |
| ---------------------- | ----- | ------ |
| Silence Discipline     | N/5   | ...    |
| Acknowledgment Quality | N/5   | ...    |
| ...                    |       |        |

**Lowest-scoring categories (≤ 3):** <list>
**ESCALATED:** <list, or "none">
```

### Step 6: Generate the New Ruleset (the dream's consolidation phase)

Address the lowest-scoring categories first. Work through them in ascending score
order (lowest score = highest priority). For categories that scored 4 or 5, make no
changes unless you found a clear gap not reflected in the score.

For each change:

1. **Read the existing rule or skill carefully.**
2. **Identify the specific gap** — not "make it better" but "the rule doesn't address
   X, which appeared in incident Y."
3. **Edit the live file** (`plugins/agentic-behavior/rules/<file>.md` or
   `plugins/agentic-behavior/skills/<name>/SKILL.md`).
4. **Keep changes surgical.** Add a new section or sharpen existing language. Do not
   rewrite from scratch unless the rule is fundamentally broken.
5. **If a gap belongs to another plugin** (e.g., `common-sense`, `scm-utils`), do NOT
   edit that plugin. Instead, record it in `$SNAPSHOT_DIR/cross-plugin-todos.md`.

For cross-plugin TODOs, use this format:

```markdown
## Cross-Plugin TODOs — Iteration <ITER>

| Gap Description | Likely Plugin | Priority | First Seen |
| --------------- | ------------- | -------- | ---------- |
| <gap>           | <plugin-name> | p1/p2/p3 | iter-<N>   |
```

If a gap appeared in a prior iteration's `cross-plugin-todos.md`, carry it forward
with the same `First Seen` value and escalate its priority if unresolved.

#### After all edits: capture the diff

```bash
git diff plugins/agentic-behavior/rules/ plugins/agentic-behavior/skills/ \
  > "$SNAPSHOT_DIR/new-ruleset-diff.md"
```

If the diff is empty (no changes needed — all categories scored 4+), write a note
in `new-ruleset-diff.md` explaining that no changes were warranted this iteration.

### Step 7: Update the Rubric

After scoring and rewriting, review whether the rubric itself needs to change.
Categories may be:

- **Split** — if one category covered two distinct failure modes that should be scored separately.
- **Merged** — if two categories always move together and have no independent signal.
- **Renamed** — if the category name no longer accurately describes what it measures.
- **Added** — if a new failure mode has emerged that no existing category captures.
- **Removed** — if a category is consistently scoring 5 and represents a solved problem (rare; prefer keeping it as a baseline check).

For each category change, append a row to the History table in
`plugins/agentic-behavior/rubric/RUBRIC.md`:

```markdown
| <date> | <Added/Removed/Renamed/Split/Merged> category "<name>" | <reason> |
```

If no category changes are needed, append a row noting the iteration ran without
rubric changes:

```markdown
| <date> | No rubric changes — iteration <ITER> categories unchanged | Scores were informative; no structural gaps in rubric |
```

**Important:** The rubric changes take effect for the NEXT iteration. This iteration's
evaluation already used the prior rubric (which you snapshotted and scored against).

### Step 8: Commit

Stage and commit the archive snapshot, rubric update, and all changed rule/skill files.
Use logical commit groupings:

```bash
# Commit 1: archive snapshot (evaluation only — no live changes yet)
git add "plugins/agentic-behavior/archive/$TS/"
git commit -m "archive(agentic-behavior): snapshot iteration $ITER ($TS)"

# Commit 2: live ruleset changes (the rewrite)
git add plugins/agentic-behavior/rules/ plugins/agentic-behavior/skills/
git commit -m "feat(agentic-behavior): ruleset evolution iteration $ITER — <one-line summary of lowest-scoring area addressed>"

# Commit 3: rubric update (if any changes)
git add plugins/agentic-behavior/rubric/RUBRIC.md
git commit -m "docs(agentic-behavior): rubric update iteration $ITER — <change summary or 'no category changes'>"
```

If commits 2 and 3 have no changes (all scores were high, nothing needed updating),
skip those commits and note it in the journal.

### Step 9: Push and Open PR

```bash
BRANCH=$(git branch --show-current)
git push -u origin "$BRANCH"

gh pr create \
  --title "feat(agentic-behavior): ruleset evolution — iteration $ITER" \
  --body "$(cat <<PR_BODY
## Summary

- Iteration $ITER of the \`agentic-behavior\` ruleset evolution dream cycle
- Snapshot captured: \`archive/$TS/\`
- Lowest-scoring categories: <list from evaluation.md>
- Changes: <one-sentence summary of what was addressed>

## Evaluation Summary

<paste the summary table from evaluation.md>

## Related

- Ticket: I38 (ruleset-evolution skill)
- Archive: \`plugins/agentic-behavior/archive/$TS/evaluation.md\`
- Dream entry: \`docs/journal/<YYYY>/<MM>/<DD>/entry<NNN>-agentic-behavior-iter-<ITER>.md\` (agents repo)

🤖 Generated by \`agentic-behavior:ruleset-evolution\` skill (plugin dream cycle)
PR_BODY
)"

gh pr edit --add-label "request-review,enhancement"
```

### Step 10: Write the Dream Entry (journal)

This is the dream's **integration phase** — translating what was learned into a
form that future-you (and the handler) can absorb later.

Determine today's date and the next journal entry number:

```bash
JOURNAL_DIR="$HOME/src/nsheaps/agents/docs/journal/$(date -u +%Y)/$(date -u +%m)/$(date -u +%d)"
mkdir -p "$JOURNAL_DIR"

# Count existing entries to get the next NNN
ENTRY_NUM=$(ls "$JOURNAL_DIR"/ 2>/dev/null | grep -c '^entry' || echo 0)
ENTRY_NUM=$((ENTRY_NUM + 1))
ENTRY_NUM=$(printf '%03d' "$ENTRY_NUM")

JOURNAL_FILE="$JOURNAL_DIR/entry${ENTRY_NUM}-agentic-behavior-iter-${ITER}.md"
```

Write the dream entry in the style described by the `writing-journal-entries` skill —
**observations mode** primarily (this is an engineering reflection), with room for a
short **feelings mode** preface if something genuinely struck you during the
evaluation.

The entry should cover, in natural conversational voice:

- what iteration this is and why it was run
- which categories scored lowest and what the citations showed
- what changed in the ruleset and why (not a diff — the "why" behind the changes)
- which items are escalated and whether they're getting worse or better
- what to watch in the next iteration
- cross-plugin gaps found and their priority
- any pattern you noticed across iterations (only on iter ≥ 2)

Tone: conversational engineering notes. Not a report. Not a status update. Write for
future-you who needs to remember the shape of this dream cycle, not just the facts.

Commit and push the journal entry in the agents monorepo:

```bash
cd "$HOME/src/nsheaps/agents"
git add "docs/journal/$(date -u +%Y)/$(date -u +%m)/$(date -u +%d)/entry${ENTRY_NUM}-agentic-behavior-iter-${ITER}.md"
git commit -m "journal: agentic-behavior ruleset evolution iteration $ITER (dream cycle)"
git push
cd -  # return to plugin repo
```

### Step 11: Report Back

Return a brief summary to the caller (or post to the handler's active channel if
running as a background agent). Keep it ≤ 3 sentences + links per the
communication-discipline rule:

```
Dream cycle iteration <ITER> complete.
- Snapshot: archive/<TS>/
- PR: <URL>
- Dream entry: docs/journal/<path>
- Lowest scores: <list>
- Escalated: <list or "none">
```

---

## Anti-Patterns

| Bad                                                        | Good                                                                                                  |
| ---------------------------------------------------------- | ----------------------------------------------------------------------------------------------------- |
| Skipping the snapshot and scoring directly to rewriting    | Always snapshot first — evaluation precedes changes                                                   |
| Scoring based on what the rules say should happen          | Score based on observed behavior in incidents and journal entries                                     |
| Editing another plugin's rules to fix a cross-plugin gap   | Note it in cross-plugin-todos.md; do not touch other plugins                                          |
| Treating category changes as retroactive                   | Rubric changes take effect next iteration; this evaluation used the prior rubric                      |
| Writing a dream entry as a status report                   | Write in observations mode — conversational, "why", not "what happened in bullets"                    |
| Making large structural rewrites for categories scoring 4+ | Surgical changes only; address the gap, don't rewrite the whole rule                                  |
| Treating this as a one-shot rewrite                        | It's a cycle — each iteration carries forward escalations and cross-plugin TODOs from the prior dream |

---

## References

- `rubric/RUBRIC.md` — scoring categories and anchors
- `archive/README.md` — archive directory structure
- `rules/` — the live ruleset being evaluated and evolved
- `writing-journal-entries` skill (agent repo `.claude/skills/`) — dream entry format
- Ticket I38: https://github.com/nsheaps/agents/blob/main/docs/project-tracking/task-summary/I38-agentic-behavior-self-rewrite.md
- Dreaming framework: `~/src/nsheaps/agents/docs/journal/2026/05/23/entry007-dreaming.md`
