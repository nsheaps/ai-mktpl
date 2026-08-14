# Cloud session verification: plugin install, SessionStart hooks, and Jack credentials

**Date:** 2026-08-14
**Environment:** Claude Code on the web (remote execution, `CLAUDE_CODE_REMOTE=true`)
**Repo under test:** `nsheaps/ai-mktpl`, branch `claude/plugin-hooks-jack-credentials-cif7qe`

## Summary

| #   | Check                                        | Result                              |
| --- | -------------------------------------------- | ----------------------------------- |
| 1   | Plugins install in a cloud session           | **PASS**                            |
| 2   | SessionStart hooks fire                      | **PASS**                            |
| 3   | Commits authored with Jack's credentials     | **FAIL** — blocked by egress policy |
| 4   | GitHub API reachable with Jack's credentials | **FAIL** — blocked by egress policy |

Checks 3 and 4 fail for a single shared reason: **the agent egress proxy blocks
every GitHub App API path**, so no installation token can be minted in this
environment. This is an environment/policy constraint, not a defect in the
`1pass` or `github-app` plugins — the plugin logic was verified correct up to
the blocked call.

## 1. Plugin installation — PASS

All 18 `ai-mktpl` marketplace plugins are present in the cache, matching the
versions resolved from `marketplace.json`:

```
/root/.claude/plugins/cache/ai-mktpl/
  1pass  agentic-behavior  common-sense  dangerous-bypass  data-serialization
  deep-research  discord  edit-utils  git-spice  github  github-app  mise
  scm-utils  sequential-thinking  shared-lib  skills-maintenance  todo-sync
  web-auto-approve
```

Every plugin enabled in `.claude/settings.json` resolved to a cached version.
Note this contradicts the historical symptom recorded in
`.claude/rules/ongoing-issues.md` (issue #745) for **this** repo — `ai-mktpl`
carries the `.claude/hooks/session-start/01-install-plugins.sh` workaround, and
it worked.

## 2. SessionStart hooks — PASS

`shared-lib` is the clearest witness because it writes an invocation log:

```
/root/.claude/plugins/data/shared-lib-ai-mktpl/sync-lib.invocations.log
2026-08-13T17:35:23Z event=unknown version=1.0.5 outcome=synced-9 ...
2026-08-13T17:35:24Z ... outcome=noop
(6 invocations total)
```

It synced all 9 shared libraries into its persistent data dir:

```
add-permission.sh  env-file.sh  env-local-target.sh  hook-logging.sh
hook-output.sh  log.sh  plugin-config-read.sh  safe-settings-write.sh
tool-install.sh
```

Persistent data dirs were created for 10 plugins, confirming hooks ran across
the set — not just one.

### Caveat: `mise` tool install is partially broken here

`mise install -y` fails for `github:nsheaps/op-exec@0.1.26`:

```
HTTP status client error (403 Forbidden) for url
(https://api.github.com/repos/nsheaps/op-exec/releases?per_page=100)
{"message":"GitHub access is not enabled for this session. An org admin must
connect the Claude GitHub App for this organization."}
```

Backend-`github:` mise tools cannot resolve because the proxy blocks the
GitHub releases API. A stale `op-exec 0.1.17` from the image remains installed,
so the pin in `mise.toml` is **not** honoured in cloud sessions.

Separately, `mise` is installed but **not activated** in the agent's Bash
environment — `op`, `op-exec`, and `gh` are all installed under
`/root/.local/share/mise/installs/` but absent from `PATH`, and
`CLAUDE_ENV_FILE` is unset. Any hook relying on bare `op` on `PATH` sees it as
missing.

## 3 & 4. Jack credentials — FAIL (egress policy)

### The credential chain is configured correctly

`.claude/plugins.settings.yaml` wires it up as intended:

```yaml
1pass:
  opExec:
    items: ["op://Agent-Jack/ENVIRONMENT"]
github-app:
  ref: "op://Agent-Jack/github--app--jack"
```

### Everything up to the token exchange works

Verified step by step:

1. `op whoami` → authenticates as `SERVICE_ACCOUNT` (integration
   `BTDBO7KDGVBDNIKUKHYKUPIPGM`). **OK**
2. `op://Agent-Jack/ENVIRONMENT` is readable and carries `GITHUB_APP_ID`,
   `GITHUB_INSTALLATION_ID`, `GITHUB_APP_PRIVATE_KEY`. **OK**
3. Those fields hold **nested** `op://Agent-Jack/github--app--jack/...`
   references. Following them one more hop yields real values (App ID 7 chars,
   installation ID 9 chars, a 1674-byte PEM with a valid `BEGIN` header). **OK**
   (`op read` does _not_ dereference recursively — that is `op-exec`'s job,
   and `op-exec` is not on `PATH`; see §2.)
4. `github-app/bin/generate-token.sh` with those values → **BLOCKED**:

```
Token exchange failed (HTTP 403):
{"message":"Access to this GitHub API path is not permitted through this proxy."}
```

### Which GitHub API paths the proxy permits

Probed with the injected `GH_TOKEN`:

| Method | Path                                    | Code | Reason                                              |
| ------ | --------------------------------------- | ---- | --------------------------------------------------- |
| GET    | `/user`                                 | 200  | —                                                   |
| GET    | `/rate_limit`                           | 200  | —                                                   |
| GET    | `/repos/nsheaps/ai-mktpl`               | 403  | GitHub access is not enabled for this session       |
| GET    | `/repos/nsheaps/ai-mktpl/pulls`         | 403  | GitHub access is not enabled for this session       |
| GET    | `/app`                                  | 403  | **Path not permitted through this proxy**           |
| POST   | `/app/installations/{id}/access_tokens` | 403  | **Path not permitted through this proxy**           |
| GET    | `/installation/repositories`            | 403  | Sessions are bound to their configured repositories |
| GET    | `/users/jack-nsheaps[bot]`              | 403  | Sessions are bound to their configured repositories |

All GitHub App endpoints are denied at the proxy. Per `/root/.ccr/README.md`,
a 403 from the proxy is an organization egress-policy denial that must be
reported rather than worked around.

### Consequences

- **No Jack installation token can be minted in this environment.** The
  `github-app` SessionStart hook correctly detects missing credentials and
  skips; its data dir is empty (no `github-app.pem`, no `github-token`, no
  isolated `gh/` or `git/config`).
- **Commits cannot be authored as Jack.** Git identity in this session is
  `Claude <noreply@anthropic.com>`; `GIT_AUTHOR_*` / `GIT_COMMITTER_*` are
  unset and `GIT_CONFIG_GLOBAL` is not isolated.
- **The bot user ID cannot be resolved** — `/users/jack-nsheaps[bot]` is also
  blocked, so even a manual identity override is unsafe. The plugin's own
  BUG-7 guard covers exactly this case and deliberately refuses to guess:

  > Rather than silently produce miscredited commits, refuse to configure git
  > identity.

  That guard behaved correctly. **This report does not override it** — the
  accompanying commit is intentionally _not_ forged with a Jack identity.

- **The effective GitHub identity is `nsheaps`**, not Jack: both the injected
  `GH_TOKEN` and the `mcp__github__*` server resolve to user `nsheaps`
  (id 1282393). Repo reads/writes work only through the session's MCP server
  and git proxy, not through raw-token REST calls.

## Recommended follow-ups

1. **Decide whether Jack-authored commits are in scope for cloud sessions at
   all.** If yes, the GitHub App token-exchange path must be allowed by the
   org egress policy — no client-side change can substitute.
2. **Make `github-app` failure louder in cloud sessions.** Today the hook logs
   and exits 0; the session then silently commits as a different identity. A
   visible `systemMessage` when credentials are configured (`ref:` is set) but
   unreachable would surface the fallback immediately.
3. **Do not rely on bare `op` / `op-exec` on `PATH` in hooks.** Resolve them
   through `mise which` or an explicit install path, since mise is not
   activated in the agent Bash environment.
4. **Pin `op-exec` to a non-`github:` backend** (or vendor it), so the
   `mise.toml` pin is honoured where the GitHub releases API is blocked.
