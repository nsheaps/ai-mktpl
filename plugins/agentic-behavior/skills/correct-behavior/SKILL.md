---
name: correct-behavior
description: >-
  Use this skill when the user says you did something wrong, made a mistake, or
  wants to correct your behavior. Trigger phrases include "don't do that",
  "that's wrong", "stop doing X", "you should have done Y", "correct yourself",
  "fix your behavior", "remember to always/never", or any feedback about
  incorrect AI actions that should be prevented in the future.
argument-hint: "[SCOPE] <description of what I did wrong>"
allowed-tools: Read, Glob, Grep, Edit, Write, Bash(git status:*), Bash(git diff:*), Bash(git log:*), Bash(git rev-parse:*), Bash(git add:*), Bash(git commit:*), Bash(git push:*), Bash(git checkout:*), Bash(gh pr:*), Bash(ls:*), Bash(pwd:*), Bash(mkdir:*), AskUserQuestion
---

<!-- This skill shares its implementation with the /correct-behavior command.
     The command file is the single source of truth — see commands/correct-behavior.md.
     This SKILL.md exists solely for the `description` frontmatter which enables
     auto-recall triggering on matching phrases. -->

!`cat "${CLAUDE_PLUGIN_ROOT}/commands/correct-behavior.md" | tail -n +8`
