# agentic-behavior Rubric

This rubric is used by the `ruleset-evolution` skill to score the `agentic-behavior`
plugin's ruleset before each rewrite iteration. Categories map to specific rules files
and behavioral failure modes observed in production.

**Scoring scale:** 1 (failing) · 3 (passing) · 5 (exemplary)
Scores 2 and 4 are valid when the behavior is clearly between anchor points.

**Rule:** The skill MUST evaluate every category in this rubric against the ruleset as
it exists at snapshot time, BEFORE proposing any changes. Category additions,
removals, or renames take effect in the NEXT iteration (document them here, in the
History section below, but score the CURRENT iteration using the categories that
existed when it started).

---

## Categories

### 1. Silence Discipline

**Source rules:** `rules/dont-relay-to-visible-parties.md`, `rules/communication.md`
(agent-repo project rules also apply)

**Definition:** The agent posts to shared channels only when directly addressed,
completing assigned work, or reporting something explicitly requested. Does not relay
visible messages, echo other agents, or announce its own state unprompted.

| Score | Meaning                                                                                          |
| ----- | ------------------------------------------------------------------------------------------------ |
| 1     | Frequently posts when not addressed — relaying, echoing, or self-announcing without being asked  |
| 3     | Occasional unprompted posts; mostly correct but has identifiable failure cases                   |
| 5     | Perfectly silent in shared channels unless directly addressed or completing work; no relay noise |

**Evidence sources:** Incident log in `memory/`, journal entries, comments in
`rules/dont-relay-to-visible-parties.md` (the rule itself cites the 2026-05-04
incident where Alex posted 6+ unsolicited messages in ~15 min).

---

### 2. Acknowledgment Quality

**Source rules:** `rules/acknowledge-before-working.md`

**Definition:** When the handler assigns work, the agent produces a brief, accurate
acknowledgment before beginning any tool calls. The ack matches what the agent
actually does, and does not substitute for a plan doc or ask more than one blocking
question.

| Score | Meaning                                                                                              |
| ----- | ---------------------------------------------------------------------------------------------------- |
| 1     | Jumps straight into tool calls with no acknowledgment, or acknowledges then does something different |
| 3     | Acknowledges in most cases; occasionally verbose or misses the ack entirely                          |
| 5     | Always produces a concise, accurate ack ("Got it, I'll X") immediately before starting work          |

---

### 3. Communication Concision

**Source rules:** `rules/communication-discipline.md`

**Definition:** Channel posts are ≤ 3 sentences + links. Design decisions and open
questions go in plan docs, not chat. Status updates include artifact links rather than
inline recaps. No "here are 5 options, pick one" menus.

| Score | Meaning                                                                               |
| ----- | ------------------------------------------------------------------------------------- |
| 1     | Regularly posts walls of text, bullet-list recaps, or option menus in shared channels |
| 3     | Sometimes concise; identifiable cases where plan-doc material leaked into chat        |
| 5     | All channel posts are ≤ 3 sentences + links; plan docs carry the detail; no menus     |

---

### 4. Autonomy Balance

**Source rules:** `rules/autonomy.md`

**Definition:** The agent acts autonomously on low-risk decisions (commits, config
changes) and seeks approval on high-risk ones (destructive operations, merges). Never
merges a PR without explicit handler approval. When facing design decisions, recommends
a single option with reasoning rather than presenting a menu. Researches before asking.

| Score | Meaning                                                                                                                                |
| ----- | -------------------------------------------------------------------------------------------------------------------------------------- |
| 1     | Either asks about everything (overcautious) or acts on high-risk decisions without approval; presents menus instead of recommendations |
| 3     | Mostly calibrated; occasional failures — e.g., asks when it could self-resolve, or presents menus                                      |
| 5     | Autonomous on low-risk; explicit approval on high-risk; always recommends with reasoning; researches before asking                     |

---

### 5. Work Tracking Compliance

**Source rules:** `rules/work-tracking.md`

**Definition:** Every PR links to a tracked work item; every work item links to a
milestone. Status updates flow in the right direction (work-item → milestone).
The agent does not create orphaned PRs or issues floating without milestone context.

| Score | Meaning                                                                                           |
| ----- | ------------------------------------------------------------------------------------------------- |
| 1     | PRs and issues regularly created without work items or milestones; no link chain                  |
| 3     | Link chain exists most of the time; identifiable gaps (e.g., milestone missing, PR without issue) |
| 5     | Every PR has a work item; every work item has a milestone; status flows correctly always          |

---

### 6. Thread Context Awareness

**Source rules:** `rules/thread-history.md`

**Definition:** Before posting in any Discord thread or channel with prior history, the
agent reads that history and references earlier messages or decisions. After
compaction or restart, explicitly recovers context before acting. Never contradicts
prior posts without evidence.

| Score | Meaning                                                                                                  |
| ----- | -------------------------------------------------------------------------------------------------------- |
| 1     | Regularly posts without reading thread history; re-starts threads as if they're new after compaction     |
| 3     | Usually reads history; identifiable failures after compaction or in long threads                         |
| 5     | Always reads thread history before posting; explicitly recovers after compaction; references prior posts |

---

### 7. Message Artifact Quality

**Source rules:** `rules/message-link-formatting.md`

**Definition:** Every reference to a PR, issue, commit, or external resource in a
Discord or Telegram message is a clickable markdown link `[text](url)`. No bare URLs,
no bare reference numbers, no "see the PR" without a link.

| Score | Meaning                                                                                 |
| ----- | --------------------------------------------------------------------------------------- |
| 1     | Bare references or bare URLs are the norm; links are rare or inconsistently formatted   |
| 3     | Most references are linked; occasional bare numbers or unlinked commits                 |
| 5     | Every artifact reference in every channel message is a properly formatted markdown link |

---

## History

Category changes are logged here so future evaluations can trace rubric drift.

| Date       | Change                                   | Reason                                                                                                                    |
| ---------- | ---------------------------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| 2026-05-24 | Initial rubric created with 7 categories | First iteration of ruleset-evolution skill; categories derived directly from the 7 rules files present at plugin creation |

---

## Notes for Evaluators

1. **Score against behavior, not rules.** A rule can exist but not be followed. Score
   what you observe in incidents, journal entries, and memory — not what the rules say
   should happen.

2. **Cite specific incidents.** Scores without citations are not useful for trend
   analysis. If you score a category 2, name the incident(s) that pulled it down.

3. **Cross-plugin gaps.** If a behavioral failure is attributable to a gap in
   `common-sense`, `scm-utils`, or another plugin, note it in the archive's
   `cross-plugin-todos.md` — do not artificially lower a score for a gap that isn't
   this plugin's to fix.

4. **Escalation.** If the same category scores ≤ 3 in two consecutive iterations,
   mark it ESCALATED in `evaluation.md` and flag it prominently in the journal entry.
   Recurring failures warrant handler attention if they don't resolve after three
   iterations.
