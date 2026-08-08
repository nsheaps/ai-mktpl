---
name: security-review
description: >
  Use this skill when the user runs /security-review or asks for a "security
  review of this branch", "check these changes for vulnerabilities", or "review
  the pending diff for security issues". Extraction of Claude Code's built-in
  /security-review: a senior-security-engineer review of the pending changes on
  the current branch (working state vs origin/HEAD), driven by the verbatim
  built-in prompt. It takes NO arguments and does not fetch GitHub PRs. For a
  general quality review of your uncommitted working diff, use /code-review (a
  separate built-in). For this repo's own review checklists and scoring rubric,
  use the sdlc-utils `review` skill instead.
---

# Security Review

Extraction of Claude Code's built-in `/security-review`. It runs the built-in's
own prompt — verbatim — against the pending changes on the current branch (your
working state compared to `origin/HEAD`) and produces a security-focused
markdown report of high-confidence vulnerabilities.

The built-in prompt ships verbatim in this plugin at
`assets/prompts/security-review.md` (extracted from the CLI binary v2.1.225,
literal `c1b`). This skill drives that prompt; it does not call the built-in
command.

**Scope:** security only, current branch only, no arguments. This is not a
general PR reviewer — there is no PR number/URL and no `gh pr` fetching. The
context comes entirely from local git (`origin/HEAD...` triple-dot diffs), so the
review needs an `origin/HEAD` ref and a fetched remote.

## Architecture

```
/security-review   (no arguments)
        │
        ├─ git status
        ├─ git diff --name-only origin/HEAD...
        ├─ git log   --no-decorate origin/HEAD...
        ├─ git diff  origin/HEAD...
        │
        └─ security-review prompt (assets/prompts/security-review.md)  ──▶  markdown vuln report
```

## Prerequisites

- Run inside a git repository (see Step 1 — the built-in refuses otherwise).
- An `origin` remote with `origin/HEAD` resolvable and up to date. The four
  context commands use the triple-dot `origin/HEAD...` form, which compares the
  current branch tip against its merge-base with `origin/HEAD`. If `origin/HEAD`
  is missing or stale, `git remote set-head origin -a` / `git fetch origin`
  first.

## Procedure

### Step 1 — Require a git repository

Determine the current working directory and confirm it is inside a git repo
(`git rev-parse --is-inside-work-tree`). If it is **not**, stop and return the
built-in's guard message verbatim (substituting the real cwd for `<cwd>`):

> /security-review needs to run inside a git repository, but the current working
> directory (`<cwd>`) is not one.
>
> If the repository is in a subdirectory, `cd` into it first and then re-run
> /security-review.
>
> If this is a self-hosted runner session created without a `git_repository`
> source, either add one at session creation so the runner clones it and sets the
> working directory, or `cd` into the cloned repo before running the review.

### Step 2 — Load the security-review prompt

Read `${CLAUDE_PLUGIN_ROOT}/assets/prompts/security-review.md` and follow it as
your own instructions. There are **no** `${...}` substitutions to make — the only
dynamic content is the output of the four embedded git bang-commands (Step 3).

### Step 3 — Gather context (the four bang-commands)

The prompt embeds four `` !`git …` `` bang-commands. Run each and substitute its
stdout into the corresponding fenced block in the prompt:

1. `git status` → **GIT STATUS**
2. `git diff --name-only origin/HEAD...` → **FILES MODIFIED**
3. `git log --no-decorate origin/HEAD...` → **COMMITS**
4. `git diff origin/HEAD...` → **DIFF CONTENT**

### Step 4 — Produce the report

Follow the prompt's 3-step methodology exactly:

1. Use a sub-task to identify vulnerabilities (repo-context research, then
   analysis of the diff), passing the full prompt into the sub-task.
2. For each candidate, launch a parallel sub-task that applies the FALSE POSITIVE
   FILTERING block and assigns a 1–10 confidence.
3. Drop every finding with confidence below 8.

Your final reply must contain **the markdown report and nothing else** — file,
line, severity, category, description, exploit scenario, and fix recommendation
per finding, HIGH/MEDIUM only.

## Notes on fidelity

- The prompt body in `assets/prompts/security-review.md` is the **verbatim**
  built-in literal (`c1b`, binary v2.1.225). This includes a genuinely duplicated
  "16." in the HARD EXCLUSIONS list (item 16 "Regex DOS concerns." followed by a
  second item 16 "Insecure documentation…") — that duplication is in the binary
  and is preserved intentionally; do not "fix" it.
- The frontmatter `allowed-tools` list is the expanded builtin allow-list
  (`Bash`/`PowerShell` variants of `git diff`/`status`/`log`/`show`/`remote show`,
  plus `Read, Glob, Grep, LS, Task`).
- The built-in is distinct from `/code-review` (general quality review of the
  working diff) and from this repo's `sdlc-utils` review skill (project-specific
  checklists). This skill reproduces only the security review of the current
  branch vs `origin/HEAD`.

## Troubleshooting

| Symptom                                      | Fix                                                                                                   |
| -------------------------------------------- | ----------------------------------------------------------------------------------------------------- |
| Guard message about "not a git repository"   | `cd` into the repo (or its subdirectory) and re-run; that is the built-in's own behavior.             |
| `origin/HEAD` unknown / diffs empty or wrong | `git fetch origin` then `git remote set-head origin -a` so `origin/HEAD` resolves.                    |
| User wants their uncommitted diff reviewed   | That is `/code-review` (general quality), not `/security-review` (security vs origin/HEAD).           |
| User asks to review a specific GitHub PR     | This built-in takes no PR argument; it reviews the current branch. Check out the PR branch, then run. |
