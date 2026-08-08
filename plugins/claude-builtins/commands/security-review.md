---
name: security-review
description: Complete a security review of the pending changes on the current branch
allowed-tools: Bash(git diff *), PowerShell(git diff *), Bash(git status *), PowerShell(git status *), Bash(git log *), PowerShell(git log *), Bash(git show *), PowerShell(git show *), Bash(git remote show *), PowerShell(git remote show *), Read, Glob, Grep, LS, Task
---

# Security Review

Extraction of Claude Code's built-in `/security-review`: a senior
security engineer review of the pending changes on the current branch, comparing
your working state against `origin/HEAD`. The prompt body is stored verbatim in
`assets/prompts/security-review.md`.

The builtin takes **no arguments**. It reviews the current branch vs
`origin/HEAD` — there is no PR number, URL, or extra-instruction plumbing. (For a
general quality review of your uncommitted working diff, use `/code-review`, a
separate builtin.)

Invoke the **`security-review`** skill and follow it end to end.

## What to do

1. **Require a git repository.** Determine the current working directory and
   check whether it is inside a git repo. If it is **not**, stop and tell the
   user (mirroring the builtin's guard):

   > /security-review needs to run inside a git repository, but the current
   > working directory (`<cwd>`) is not one.
   >
   > If the repository is in a subdirectory, `cd` into it first and then re-run
   > /security-review.
   >
   > If this is a self-hosted runner session created without a `git_repository`
   > source, either add one at session creation so the runner clones it and sets
   > the working directory, or `cd` into the cloned repo before running the
   > review.

2. Recall and follow the **`security-review`** skill
   (`skills/security-review/SKILL.md`).

3. Load `${CLAUDE_PLUGIN_ROOT}/assets/prompts/security-review.md`. It embeds four
   git bang-commands that supply the review's context; run each and substitute
   its output into the prompt:
   - `` !`git status` `` → GIT STATUS
   - `` !`git diff --name-only origin/HEAD...` `` → FILES MODIFIED
   - `` !`git log --no-decorate origin/HEAD...` `` → COMMITS
   - `` !`git diff origin/HEAD...` `` → DIFF CONTENT

4. Follow the prompt's 3-step methodology (identify vulnerabilities in a
   sub-task, filter false positives in parallel sub-tasks, drop anything below
   confidence 8) and reply with the markdown report and nothing else.
