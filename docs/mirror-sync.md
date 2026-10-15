# Mirror sync

`nsheaps/ai-mktpl` and `oura-health-playground/nsheaps-ai-mktpl` are kept in sync in both
directions by [`sync-mirror.yaml`](../.github/workflows/sync-mirror.yaml). Merge or push to
`main` on either side and the other follows. The workflow file is identical in both repos (it
syncs itself), and the logic lives in [`mise/tasks/sync-mirror`](../mise/tasks/sync-mirror).

## How it behaves

On each run the workflow compares `main` on both repos:

| State                    | Action                                                                |
| ------------------------ | --------------------------------------------------------------------- |
| Equal                    | Nothing                                                               |
| Peer behind this repo    | Fast-forward the peer                                                 |
| This repo behind peer    | Fast-forward this repo (needs `SYNC_SELF_DEPLOY_KEY`, see below)      |
| Diverged, no conflicts   | Merge, push the merge commit to both                                  |
| Diverged, with conflicts | Fail with the conflicting files listed; nothing is pushed (see below) |

Pushes are never forced. A rejected push (the other side moved first) is retried from a fresh
fetch. The merge commit is deterministic (parents ordered by SHA, fixed identity and dates), so
runs on both sides that merge the same two tips produce the same commit and agree instead of
rejecting each other.

**Why it doesn't loop.** Deploy-key pushes trigger the target repo's workflows (unlike
`GITHUB_TOKEN` pushes). The target's run then sees both sides equal and stops.

**Triggers.**

- `push` to `main`.
- `workflow_run` after `cd` completes (push or manual runs). The bump commits from `cd.yaml` carry
  `[skip ci]`, so their push never fires the sync; this carries them across.
- `workflow_dispatch`, for on-demand runs.

**Version bumps happen on one side only.** `cd.yaml`'s `bump-and-update-marketplace` job runs only
in `nsheaps/ai-mktpl`. The mirror receives the bump commits through the sync. If both bumped,
each side would create conflicting version commits.

**Not synced:** tags (`cd/last-release` is force-moved independently per repo), branches other
than `main` unless requested through the dispatch input, and anything that isn't git (PRs,
issues, labels, settings, secrets).

## One-time setup

Two keypairs, one per repo. A deploy key can be registered on only one repo, and each key grants
write access to exactly that repo. Each private key is stored as a secret in **both** repos, in
different roles. Both are required: a run needs the self key to read and update its own repo and
the peer key for the other.

| Key                         | Public half added as deploy key (write) on | Secret in `nsheaps/ai-mktpl` | Secret in `oura-health-playground/nsheaps-ai-mktpl` |
| --------------------------- | ------------------------------------------ | ---------------------------- | --------------------------------------------------- |
| `key-ai-mktpl`              | `nsheaps/ai-mktpl`                         | `SYNC_SELF_DEPLOY_KEY`       | `SYNC_PEER_DEPLOY_KEY`                              |
| `key-oura-playground-mktpl` | `oura-health-playground/nsheaps-ai-mktpl`  | `SYNC_PEER_DEPLOY_KEY`       | `SYNC_SELF_DEPLOY_KEY`                              |

`SYNC_SELF_DEPLOY_KEY` lets a run update its own repo (pulling peer changes in).
`SYNC_PEER_DEPLOY_KEY` lets it update the other repo.

**Secrets live in the `mirror-sync` Environment, restricted to `main`.** The workflow job declares
`environment: mirror-sync`. A deploy key that bypasses `main` protection is exactly what someone
with write access would want to steal by pushing a branch with a modified workflow; the branch
policy stops that run from receiving the secrets.

Run from a trusted machine in an empty directory (needs the `gh` CLI with admin access to both
repos):

```bash
A=nsheaps/ai-mktpl
B=oura-health-playground/nsheaps-ai-mktpl

ssh-keygen -t ed25519 -N '' -C "mirror-sync: write $A" -f key-ai-mktpl
ssh-keygen -t ed25519 -N '' -C "mirror-sync: write $B" -f key-oura-playground-mktpl

# public halves -> deploy keys with write access
gh repo deploy-key add key-ai-mktpl.pub --allow-write --title mirror-sync -R "$A"
gh repo deploy-key add key-oura-playground-mktpl.pub --allow-write --title mirror-sync -R "$B"

# environment that only deploys from main
for R in "$A" "$B"; do
  echo '{"deployment_branch_policy":{"protected_branches":false,"custom_branch_policies":true}}' |
    gh api -X PUT "repos/$R/environments/mirror-sync" --input -
  gh api -X POST "repos/$R/environments/mirror-sync/deployment-branch-policies" -f name=main
done

# private halves -> environment secrets, in both roles
gh secret set SYNC_SELF_DEPLOY_KEY --env mirror-sync -R "$A" < key-ai-mktpl
gh secret set SYNC_PEER_DEPLOY_KEY --env mirror-sync -R "$B" < key-ai-mktpl
gh secret set SYNC_SELF_DEPLOY_KEY --env mirror-sync -R "$B" < key-oura-playground-mktpl
gh secret set SYNC_PEER_DEPLOY_KEY --env mirror-sync -R "$A" < key-oura-playground-mktpl

# the secrets now hold the keys; remove the local copies
shred -u key-ai-mktpl key-oura-playground-mktpl 2>/dev/null || rm -P key-ai-mktpl key-oura-playground-mktpl
rm -f key-ai-mktpl.pub key-oura-playground-mktpl.pub
```

If `main` is protected by a branch protection rule or ruleset (required PRs, required checks),
deploy-key pushes are rejected. Add **Deploy keys** to the bypass list of the ruleset on each
repo. Classic branch protection has no deploy-key bypass; use a ruleset.

## Running on demand

```bash
# preview only
gh workflow run sync-mirror.yaml -R nsheaps/ai-mktpl -f dry_run=true
# sync main now (either repo works; each run reconciles both sides)
gh workflow run sync-mirror.yaml -R oura-health-playground/nsheaps-ai-mktpl
# include other branches
gh workflow run sync-mirror.yaml -R nsheaps/ai-mktpl -f branches="main edge"
```

Locally, the same logic runs as `mise run sync-mirror` with `SYNC_SELF_URL`, `SYNC_PEER_URL`,
the two deploy-key variables, and `SYNC_KNOWN_HOSTS` set. `SYNC_DRY_RUN=true` previews.

## Resolving a conflict

If both sides changed the same lines, the run fails and lists the files. Merge in any clone and
push the result to either repo's `main`; the next sync carries it to the other.

```bash
git clone git@github.com:nsheaps/ai-mktpl.git && cd ai-mktpl
git remote add mirror git@github.com:oura-health-playground/nsheaps-ai-mktpl.git
git fetch mirror && git merge mirror/main   # resolve, commit
git push origin main                         # sync pushes it to the mirror
```

## Known limitations

- **History rewrites are undone.** If `main` is force-pushed or scrubbed on one side (for example
  to remove a leaked secret), the two sides look diverged and the sync merges the old history back
  into both. Disable the workflow (`gh workflow disable sync-mirror.yaml` in both repos), rewrite
  both repos, then re-enable it.
- **`cd` can race a sync push.** If the sync fast-forwards `nsheaps/ai-mktpl`'s `main` while the
  bump job is mid-run, the bump's `git push` is rejected and `cd` fails. The bump then waits for
  the next plugin change; re-run it with `gh workflow run cd.yaml -R nsheaps/ai-mktpl`.
- **`GITHUB_TOKEN` pushes don't trigger the sync.** Commits other workflows push that way (for
  example `sync-plugin-specs.yaml`) are carried by the next sync run, not immediately.
- **Keys give each repo write access to the other's `main`**, bypassing review, by design. Anyone
  who can change code that runs on `main` in either repo can push to both.

## Tests

```bash
bash mise/tests/sync-mirror.test.sh
```

Covers: in sync, both fast-forward directions, a clean diverged merge that is identical from
either side, a conflict (nothing pushed), loop termination from the reverse side, branch creation,
dry run, an unreadable remote failing the run, a missing deploy key, and glob branch names. It
uses local bare repos, so it does not exercise SSH, the GitHub-API host-key fetch, or the
Environment; the first real run does.
