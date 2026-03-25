# Overall Review — PR #266: Add shared-rules plugin for remote rule syncing

**Branch:** `claude/create-shared-rules-plugin-YMdMO`
**Epoch:** 1774399241

## Score Summary

| Category         | Score      | Status               |
| ---------------- | ---------- | -------------------- |
| Simplicity       | 52/100     | 🚨 Hard block        |
| Security         | 42/100     | 🚨 Hard block        |
| QA & Engineering | 62/100     | 🚨 Hard block        |
| Flexibility      | 72/100     | ⚠️ Below threshold   |
| Usability        | 76/100     | ⚠️ Below threshold   |
| Documentation    | 82/100     | ⚠️ Below threshold   |
| Best Practices   | 82/100     | ⚠️ Below threshold   |
| Repo Patterns    | 90/100     | ✅                   |
| **Overall**      | **70/100** | 🚨 **Not mergeable** |

---

## Hard Blocks

### Security (42/100) 🚨

Three exploitable vulnerabilities in the current implementation:

1. **Path traversal via `_SRC_PATH`** — only the leading `/` is stripped; `../../../.ssh` survives into `sparse-checkout` and the symlink target. Fix: reject any path containing `..` after parsing.
2. **Path traversal via `_SRC_NAME`** — the symlink name is not validated; a name like `../../../etc/cron.d` places the symlink outside `.claude/rules/`. Fix: reject names containing `/` or `..`.
3. **Git ref flag injection** — `$ref` is passed directly to `git` commands; a ref starting with `-` is interpreted as a flag. Fix: reject refs starting with `-`.
4. **Design: transitive dependency trust** — `.shared-rules.yaml` inside a cloned repo drives additional clones with no user opt-in. A compromised upstream repo can bootstrap arbitrary transitive clones. Fix: add `followDependencies: false` default; require explicit opt-in.

### Simplicity (52/100) 🚨

The ~70-line `read_source_config` function re-implements 3-tier config resolution that the shared `plugin_get_config_array` library already provides. Fix: switch source format from YAML mappings `{ name: 'value' }` to quoted `"name=value"` strings, which `plugin_get_config_array` returns natively. This eliminates `read_source_config` entirely. Also remove the legacy `owner/repo/path@ref [as name]` parse branch — this is v0.0.1 with no existing users.

### QA & Engineering (62/100) 🚨

1. **`plugin.json` missing `"hooks": "./hooks/hooks.json"`** — hooks may not register on install per the `plugin-hooks-organization.md` rule.
2. **`plugin_is_enabled` never checked** — the hook always runs regardless of the `enabled: false` setting.
3. **`[skip ci]` in commit `6b4b88c`** — explicitly prohibited by `ci-cd/conventions.md` for AI agent commits. (Historical; cannot rewrite.)
4. **Noisy commit history** — 5 standalone lint commits that should have been squashed.

---

## Below Threshold

### Flexibility (72/100) ⚠️

- GitHub-only hardcoded clone URL (`github.com`) with no documentation of constraint
- Python3 fallback assumes exactly 2-space YAML indentation
- First-match semantics: `sources: []` at project level silently suppresses user-level sources

### Usability (76/100) ⚠️

- No "Requirements" section (needs `git`, `yq`)
- `alsoSyncToUser` sets a global side-effect (affects all projects) with no warning
- "No sources configured" is a quiet log, not an actionable first-run message

### Documentation (82/100) ⚠️

- No troubleshooting section (stale symlinks, network failures, yq absent)
- `alsoSyncToUser` global side-effect not warned in README or settings file
- 60-second hook timeout has no documented rationale

### Best Practices (82/100) ⚠️

- `parse_source_ref` sets global `_SRC_*` variables — side-effecting contract not documented
- No warning when neither `yq` nor `python3` is available (silent no-op)
- `local file key="${PLUGIN_NAME}"` mixes declaration and assignment in one `local` call

---

## Individual Reports

- [Simplicity](../simplicity/REPORT.md)
- [Flexibility](../flexibility/REPORT.md)
- [Usability](../usability/REPORT.md)
- [Documentation](../documentation/REPORT.md)
- [Security](../security/REPORT.md)
- [Repo Patterns](../repo-patterns/REPORT.md)
- [Best Practices](../best-practices/REPORT.md)
- [QA & Engineering](../qa-engineering/REPORT.md)
