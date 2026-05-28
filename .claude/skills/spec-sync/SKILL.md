---
name: spec-sync
description: |
  Bidirectionally sync each plugin's SPEC.md with the file system.
  Add this skill when items exist in the FS but not in the spec, or vice versa.
  Reports all changes so you can fill in empty descriptions.
  Run when adding new skills/rules/hooks/commands to a plugin.
---

# Spec Sync

Bidirectionally syncs every plugin's `SPEC.md` with the file system:

- **FS → SPEC**: Items found on disk but missing from the spec get added (with description if available)
- **SPEC → FS**: Items listed in the spec but missing from disk get created (as minimal placeholder files)
- **Both exist**: Left alone — no overwrites
- **Deletion**: Must be done manually in both places

## Current Sync Status

!`python3 .claude/skills/spec-sync/sync.py`

## After Running

Review the output above. For any items marked `(no description — fill in manually)`, update the SPEC.md with the correct description. For newly created placeholder files, fill in the actual skill/rule content.
