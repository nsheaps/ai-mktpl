---
name: deep-research
description: |
  Use this skill when investigating undocumented behavior, internal mechanisms, or "how does X work?" questions about Claude Code or other tools where official documentation is insufficient.
  Trigger when:
  - External docs/issues don't explain the full mechanism
  - You need to trace how a feature actually works at the code level
  - Previous research findings need source-level verification
  - You're investigating behavior differences between documented and observed behavior
  This skill provides a repeatable methodology for going from "we don't know" to "here's exactly how it works, with source references."
---

# Deep Research Methodology

A repeatable playbook for investigating undocumented mechanisms, internal behaviors, and "how does X work?" questions — especially for tools like Claude Code where source isn't directly available.

## The Research Phases

### Phase 1: External Research (Low Cost, Broad Coverage)

Start with publicly available information. This is cheap and fast.

**Steps:**

1. **Search GitHub Issues** — Use `gh issue list --repo <repo> --search "<keywords>"` or WebSearch. Issues often contain the most detailed technical descriptions of behavior, including bug reports that reveal internals.
2. **Search Official Documentation** — Fetch the relevant docs pages. Note what IS documented and what's missing.
3. **Search Community Sources** — Blog posts, community plugins, Stack Overflow, Discord threads. Use WebSearch with specific technical terms.
4. **Check Related Projects** — GitHub repos that interface with the tool often reverse-engineer or document internal behavior.

**Parallelization:** Launch multiple web searches simultaneously for different aspects of the question. Use background sub-agents for fetching GitHub issues and documentation pages.

**Output:** A research report with findings, confidence levels, and explicit gaps. Save to `.claude/tmp/<topic>-research.md`.

**When to stop:** If Phase 1 answers the question with High confidence across all aspects, you're done. If any finding has Medium or lower confidence, or if there are contradictions between sources, proceed to Phase 2.

### Phase 2: Source Analysis (Higher Cost, Definitive Answers)

When external research leaves gaps, go to the source code.

**When to escalate:**

- External sources contradict each other
- Multiple feature requests exist for something that might already be implemented
- Behavior observed doesn't match documentation
- You need the exact mechanism, not just "what it does"

**Steps:**

1. **Locate source material** — Compiled binaries, decompiled JS, open-source repos, package contents
2. **Search for entry points** — Start with the user-visible behavior and trace backwards:
   - If investigating a CLI flag: search for the flag name string
   - If investigating UI behavior: search for visible text strings
   - If investigating a protocol: search for escape sequences, HTTP methods, or wire format
3. **Trace the call chain** — Once you find the entry point, follow function calls to understand the full flow
4. **Verify with multiple evidence points** — Don't trust a single grep match. Look for call sites, related functions, and configuration checks

### Phase 3: Synthesis and Verification

Combine findings and check for consistency.

**Steps:**

1. **Cross-reference Phase 1 and Phase 2** — Do the source findings explain the external observations? If not, keep digging.
2. **Correct earlier conclusions** — If source analysis contradicts your Phase 1 findings, explicitly call out the correction. Previous research was based on incomplete information — that's expected, not a failure.
3. **Document confidence levels** — Be explicit about what's confirmed vs. inferred
4. **Write the final report** — Include source references (file:line), mechanism description, and practical implications

## Navigating Decompiled Code

When working with decompiled/minified JavaScript (e.g., from Bun-compiled binaries):

### Search Strategy

**Start broad, narrow iteratively:**

```
Round 1: Search for exact strings visible in the UI
  e.g., "terminal_update_title", "DISABLE_TERMINAL_TITLE"

Round 2: Search for technical mechanism keywords
  e.g., "process.title", "\x1B]0;", "OSC", "escape"

Round 3: Search for the function/variable names found in rounds 1-2
  e.g., "function Y7A", "Y7A("

Round 4: Read surrounding context (50-100 lines) around each hit
  to understand the full flow
```

### Dealing with Obfuscation

- **Variable names are meaningless** — `toolLinuxDef`, `errorHandler_R`, etc. are artifacts of the decompiler. Focus on string literals and control flow.
- **Follow the strings** — String constants survive obfuscation. Search for known strings (error messages, prompt text, env var names) to find relevant code.
- **Multiple decompiled versions may exist** — If the investigation repo has `-deobfuscated.js`, `-renamed.js`, and `-annotated.js`, search the renamed version first (has semantic variable names where possible).
- **Module splitting helps** — Individual module files in `modules/` are easier to read than the monolithic bundle.

### What to Search For (by Investigation Type)

| Investigating...    | Search for...                                                               |
| :------------------ | :-------------------------------------------------------------------------- |
| Terminal/tab titles | `\x1B]0;`, `\x1B]1;`, `\x1B]2;`, `process.title`, `setTitle`, `windowTitle` |
| tmux integration    | `tmux`, `split-window`, `send-keys`, `rename-window`, `pane`                |
| Permission modes    | `delegate`, `bypassPermissions`, `permission_mode`, `permissionMode`        |
| Hook system         | `PreToolUse`, `PostToolUse`, `hookSpecificOutput`, `permissionDecision`     |
| Environment vars    | `CLAUDE_CODE_`, `process.env.CLAUDE`                                        |
| Agent/team system   | `CLAUDE_CODE_AGENT`, `teammate`, `team-lead`, `teamContext`                 |
| Notification system | `\x1B]9;`, `\x1B]99;`, `\x1B]777;`, `notify`                                |
| Process lifecycle   | `process.title`, `process.exit`, `process.on("exit"`                        |

## Confidence Level Framework

Use these consistently across all research reports:

| Level           | Meaning                                               | Evidence Required                                           |
| :-------------- | :---------------------------------------------------- | :---------------------------------------------------------- |
| **Very High**   | Confirmed from source code with exact line references | Decompiled source + verified call chain                     |
| **High**        | Confirmed from multiple independent external sources  | 3+ sources agree, or official docs + community confirmation |
| **Medium-High** | Strong evidence but some inference required           | 2 sources agree + logical reasoning                         |
| **Medium**      | Plausible with supporting evidence                    | 1 source + consistent with observed behavior                |
| **Low**         | Hypothesis based on limited evidence                  | Inference from related findings only                        |

### When to Revise Previous Findings

**Always revise when:**

- Source analysis contradicts external research
- A newer version of the tool changes behavior
- You find that feature requests were for behavior that HAS been implemented

**How to revise:**

1. Don't delete the old report — add a correction section or write a new report
2. Explicitly state what was wrong and why (e.g., "based on GitHub issues from older versions")
3. Provide the new evidence with source references

## Report Structure Template

```markdown
# Research: <Topic>

**Researcher**: <Name>
**Date**: <Date>
**Question**: <The specific question being investigated>

## Executive Summary

<2-3 sentence answer>

## Methodology

<Which phases were used, what sources were consulted>

## Findings

### 1. <Finding>

<Detail with source references>
**Confidence**: <Level> — <evidence summary>

### 2. <Finding>

...

## Corrections to Previous Research

<If applicable — what changed and why>

## Practical Implications

<How to use these findings>

## Open Questions

<What remains unanswered>

## Confidence Levels

| Finding | Confidence |
| :------ | :--------- |
| ...     | ...        |

## Sources

- <Source with link or file:line reference>
```

## Worked Example: Tab Title Investigation

This methodology was developed during the investigation of how Claude Code sets iTerm2 tab titles for agent team teammates.

### Phase 1: External Research

**What we did:**

- Searched 4 GitHub issues (#18326, #20441, #15802, #15082) — all said Claude Code does NOT emit OSC escape sequences
- Checked official docs — no mention of terminal title management
- Found community workarounds (claude-code-terminal-title skill, tmux-agent-indicator plugin)
- Checked iTerm2 and tmux documentation for title mechanisms

**Phase 1 conclusion (WRONG):** "Claude Code does NOT set terminal titles. Tab text comes from tmux's `automatic-rename` reading the process name."

**Confidence was Medium-High** — 4 feature requests all confirmed the gap. But the issues were from older versions.

### Phase 2: Source Analysis

**Why we escalated:** The user observed tab titles showing task descriptions like "Broadcasting Rule Verification" — which couldn't come from `automatic-rename` (that would show "claude" or "node"). Something was setting titles.

**What we searched in decompiled source (`cc-investigation` repo):**

1. `process.title` → Found `process.title = "claude"` at startup (line 418664). This explains tmux `automatic-rename`, but NOT the descriptive titles.
2. `\x1B]0` (OSC 0 escape sequence) → **Found line 174558**: `process.stdout.write(\`\x1B]0;${title}\x07\`)`
3. Traced the caller → Found `uf_()` at line 174560: an LLM call with `querySource: "terminal_update_title"` that extracts 2-3 word topics from user messages
4. Found the call site → Line 366457: triggers on every user message
5. Found the disable mechanism → `CLAUDE_CODE_DISABLE_TERMINAL_TITLE` env var

### Phase 3: Synthesis

- Phase 1 findings were based on **outdated GitHub issues** — the feature was added after those issues were filed
- The mechanism is an **LLM-powered topic extraction** → OSC 0 escape sequence pipeline
- Two separate title mechanisms exist: `process.title` (static, for tmux) and OSC 0 (dynamic, for terminals)
- Corrected the Phase 1 report and documented the full mechanism

**Full reports:**

- Phase 1: [`.claude/tmp/tab-title-mechanism-research.md`](https://github.com/nsheaps/claude-utils) (in claude-utils)
- Phase 2: [`.claude/tmp/tab-title-mechanism-source-analysis.md`](https://github.com/nsheaps/claude-utils) (in claude-utils)

### Key Lesson

**External research can be confidently wrong.** Four GitHub issues all said the feature didn't exist — because they were from older versions. The confidence level framework caught this: "Medium-High" left room for revision. When observed behavior contradicted the research, Phase 2 (source analysis) provided the definitive answer.

## Tips for Researchers

1. **Save everything to files** — Reports, raw data, intermediate findings. Context compaction will destroy in-memory state. Files survive.
2. **Use sub-agents for parallel fetches** — Launch background agents to fetch GitHub issues, docs pages, and URLs simultaneously.
3. **Search decompiled code with Grep, not Bash** — Built-in Grep handles large files better and doesn't require piping.
4. **Read 50-100 lines of context** — A single grep match is not enough. Always read surrounding context to understand the full function.
5. **Track what you tried** — Document search terms that didn't work, so you (or a future researcher) don't repeat them.
6. **Confidence levels are mandatory** — Every finding needs an explicit confidence level. This is how you know when to escalate to source analysis.
7. **Correct previous research openly** — Being wrong in Phase 1 is expected. Document the correction and why the earlier conclusion was wrong.
