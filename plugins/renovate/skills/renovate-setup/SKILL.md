---
name: renovate-setup
description: >
  Use this skill when setting up or debugging Renovate auto-merge, configuring
  Renovate in a repo, or diagnosing why Renovate PRs are not auto-merging.
---

# Renovate Setup & Auto-Merge Debugging

Renovate is a dependency update bot. This skill covers enabling auto-merge on
repos and debugging when Renovate PRs get stuck.

## Enabling Auto-Merge on a Repo

Two steps are required: the repo setting AND the declarative settings file.

### 1. Enable via GitHub API

```bash
gh repo edit nsheaps/<repo> --enable-auto-merge --delete-branch-on-merge
```

Run separately for each repo. This sets the GitHub repo-level flag.

### 2. Update `.github/settings.yaml`

If the repo uses a declarative settings workflow (most nsheaps repos do), add
`allow_auto_merge: true` to the `repository:` block:

```yaml
repository:
  allow_auto_merge: true
  delete_branch_on_merge: true
  # ... other settings
```

Commit this to main. Without this, the settings workflow may reset the flag.

## Renovate Config: `extends` Pattern

Renovate configs in nsheaps repos should extend from `nsheaps/renovate-config`.
The correct file name changed from `default.json` to `default.json5`:

```json5
// renovate.json5
{
  $schema: "https://docs.renovatebot.com/renovate-schema.json",
  extends: [
    "github>nsheaps/renovate-config", // uses default.json5 automatically
  ],
}
```

Check `nsheaps/renovate-config` for what the shared config contains (automerge
settings, schedule, package rules, etc.).

## Auto-Merge Debugging Checklist

When a Renovate PR is stuck and not auto-merging:

1. **Repo setting enabled?**

   ```bash
   gh api repos/nsheaps/<repo> --jq '.allow_auto_merge'
   # should return: true
   ```

2. **PR has auto-merge queued?**

   ```bash
   gh pr view <N> --repo nsheaps/<repo> --json autoMergeRequest
   # autoMergeRequest should be non-null
   ```

   If null, enable it:

   ```bash
   gh pr merge <N> --repo nsheaps/<repo> --auto --squash
   ```

3. **Branch protection / rulesets blocking?**

   ```bash
   gh api repos/nsheaps/<repo>/rules/branches/main
   ```

   Common blockers:
   - `pull_request` rule requiring `required_approving_review_count: 1` → approve the PR
   - Required status checks that aren't running → check CI config

4. **Required status checks failing?**

   ```bash
   gh pr view <N> --repo nsheaps/<repo> --json statusCheckRollup
   ```

   Empty `statusCheckRollup` + BLOCKED usually means a required check is
   configured but no CI run has happened (missing workflow trigger or CI never ran).

5. **Approve if review required:**
   ```bash
   gh pr review <N> --repo nsheaps/<repo> --approve --body "Approving Renovate dependency update."
   ```

## Lint Gotcha: Mixed-Language `bin/` Directories

If a repo has both shell scripts and TypeScript/JavaScript files in `bin/`,
the bash lint CI job will fail on the non-shell files. Fix: add extension
checks to skip non-shell files:

```yaml
- name: Lint shell scripts
  run: |
    for script in bin/*; do
      [ -d "$script" ] && continue
      [ -f "$script" ] || continue
      # Skip non-shell files
      case "$script" in
        *.ts|*.js|*.py|*.rb|*.go) continue ;;
      esac
      echo "Checking $script..."
      bash -n "$script"
    done
```

This is relevant to renovate because Renovate PRs updating dependencies may
trigger CI runs that hit this lint bug and prevent auto-merge.

## References

- [nsheaps/renovate-config](https://github.com/nsheaps/renovate-config) — shared Renovate config
- [Renovate docs: automerge](https://docs.renovatebot.com/configuration-options/#automerge)
- [GitHub: enabling auto-merge](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/incorporating-changes-from-a-pull-request/automatically-merging-a-pull-request)
