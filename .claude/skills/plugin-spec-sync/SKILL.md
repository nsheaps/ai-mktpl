---
name: plugin-spec-sync
description: |
  Use this skill to sync plugin SPEC.md files with what's actually on disk (skills, rules, hooks, agents, commands). Recall when the user asks about SPEC.md drift, "are SPEC files up to date", spec scaffolding, or after adding/renaming a skill/rule/hook/command in a plugin.
---

# plugin-spec-sync

Sync plugin `SPEC.md` files with the filesystem across the entire `plugins/` directory.

## What it does

| Direction       | Action                                                                                                                                                    |
| --------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- |
| FS → SPEC       | Item exists in `skills/`, `rules/`, `commands/`, or `hooks/hooks.json` but missing from `SPEC.md` → adds stub entry, reusing description from source file |
| SPEC → FS       | Item listed in `SPEC.md` but missing from filesystem → creates stub file/dir, using SPEC description                                                      |
| Both exist      | **No update** — descriptions not synced even if they differ                                                                                               |
| Remove          | Must be removed from both places manually (never half-removed)                                                                                            |
| SPEC.md missing | Auto-generated from plugin metadata + filesystem scan with `TODO: add description` placeholders                                                           |

Hooks are synced FS → SPEC only (scaffolding `hooks.json` from SPEC is not supported).

## Current Sync Status

!`bin/sync-plugin-specs.sh 2>&1`

To sync a single plugin: `bin/sync-plugin-specs.sh --plugin <name>`

## After running

1. Review items printed above — each line shows what changed.
2. Fill in any `TODO: add description` placeholders in newly created or updated SPEC.md entries.
3. Review added skill/rule/agent/command entries and flesh out any stub files before shipping.
4. Run again to confirm idempotent — should output `No changes needed`.
