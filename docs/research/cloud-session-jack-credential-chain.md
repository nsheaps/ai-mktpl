# Cloud session verification: plugin install, SessionStart hooks, and Jack credentials

**Verification run:** 2026-08-13 (session start `17:35Z`)
**Report written:** 2026-08-14
**Environment:** Claude Code on the web (remote execution, `CLAUDE_CODE_REMOTE=true`)
**Repo under test:** `nsheaps/ai-mktpl`, branch `claude/plugin-hooks-jack-credentials-cif7qe`

## Summary

| #   | Check                                        | Result                                         |
| --- | -------------------------------------------- | ---------------------------------------------- |
| 1   | Plugins install in a cloud session           | **PASS**                                       |
| 2   | SessionStart hooks fire                      | **PARTIAL** — ran, but not via native dispatch |
| 3   | Commits authored with Jack's credentials     | **FAIL** — blocked by egress policy            |
| 4   | GitHub API reachable with Jack's credentials | **FAIL** — blocked by egress policy            |

Checks 3 and 4 both fail because the agent egress proxy denies the GitHub App
API paths, so no installation token can be minted. This is an
environment/policy constraint, not a defect in the `1pass` or `github-app`
plugins — plugin logic was verified correct up to the blocked call.

Check 2 is **not** a clean pass: the hooks demonstrably ran and had their
effects, but the available evidence indicates they were fired by this repo's
`01-install-plugins.sh` workaround rather than by Claude Code's native
SessionStart dispatch. See §2.

## 1. Plugin installation — PASS

Every plugin enabled in `.claude/settings.json` resolved to a cached version.
Counts, measured on this branch:

| Measure                                                | Count |
| ------------------------------------------------------ | ----- |
| Plugins published in `.claude-plugin/marketplace.json` | 55    |
| Plugin directories in `plugins/`                       | 58    |
| Entries in `.claude/settings.json` `enabledPlugins`    | 21    |
| …of those, set to `true` (actually enabled)            | 12    |
| `ai-mktpl` plugins present in this session's cache     | 18    |

All **12** enabled plugins resolved, spanning three marketplaces:

- `ai-mktpl` (9): `1pass`, `deep-research`, `edit-utils`, `git-spice`,
  `github-app`, `mise`, `scm-utils`, `shared-lib`, `web-auto-approve`
- `claude-plugins-official` (2): `hookify`, `plugin-dev`
- `braintrust-claude-plugin` (1): `trace-claude-code`

The 18 cached `ai-mktpl` entries are a **superset** of the 9 enabled ones —
Claude Code caches referenced plugins (including entries set to `false` and
transitive dependencies), not the whole 55-plugin marketplace. 18-of-55 is the
expected result, not a shortfall.

> **Scope note:** this check confirms _presence and resolution_ in the cache. It
> does **not** verify that cached versions match those declared in
> `marketplace.json` — no version comparison was performed.

## 2. SessionStart hooks — PARTIAL

### What is proven

The hooks ran and their side effects are present. `shared-lib` synced all 9
libraries into its persistent data dir:

```
add-permission.sh  env-file.sh  env-local-target.sh  hook-logging.sh
hook-output.sh  log.sh  plugin-config-read.sh  safe-settings-write.sh
tool-install.sh
```

and persistent data dirs were created for 10 plugins.

### What is NOT proven — and why it matters

`shared-lib` writes a diagnostic invocation log. All six entries:

```
/root/.claude/plugins/data/shared-lib-ai-mktpl/sync-lib.invocations.log
2026-08-13T17:35:23Z event=unknown version=1.0.5 outcome=synced-9 root=.../shared-lib/1.0.5
2026-08-13T17:35:24Z event=unknown version=1.0.5 outcome=noop    root=.../shared-lib/1.0.5
2026-08-13T17:36:19Z event=unknown version=1.0.5 outcome=noop    root=.../shared-lib/1.0.5
2026-08-13T17:36:48Z event=unknown version=1.0.5 outcome=noop    root=.../shared-lib/1.0.5
2026-08-13T17:37:40Z event=unknown version=1.0.5 outcome=noop    root=.../shared-lib/1.0.5
2026-08-13T17:38:07Z event=unknown version=1.0.5 outcome=noop    root=.../shared-lib/1.0.5
```

Three properties of this log limit what it can support:

1. **It is append-only and lives in `${CLAUDE_PLUGIN_DATA}`**, which
   `.claude/rules/shared-libs.md` documents as persisting across sessions. "6
   invocations" is a lifetime count for that data dir, not a per-session count.
2. **Every entry reads `event=unknown`.** Per
   `plugins/shared-lib/hooks/scripts/sync-lib.sh`, the event name is read from
   the stdin hook payload's `hook_event_name` — there is no
   `CLAUDE_HOOK_EVENT_NAME` env var. A native SessionStart dispatch supplies
   that payload.
3. **This repo's workaround fires hooks without a payload.**
   `.claude/hooks/session-start/01-install-plugins.sh` re-fires each plugin's
   hook command with `eval "$resolved_cmd"` inside a subshell that sets only
   `CLAUDE_PLUGIN_ROOT` / `CLAUDE_PLUGIN_DATA` — **no stdin JSON**. That yields
   exactly `event=unknown`.

The usual alternative explanation for `unknown` — a missing `jq` on `PATH` —
does **not** apply here: `jq` is present at `/usr/bin/jq`.

**Conclusion:** every recorded invocation is consistent with the workaround and
inconsistent with native dispatch. This is therefore **not** a counter-example
to issue #745 — if anything it is further evidence _for_ it. An earlier draft
of this report claimed the opposite; that claim was wrong and is retracted.

To turn this into a genuine test of native dispatch, a future run should look
for a log entry with a resolved `event=SessionStart`. None exists here.

### Caveat: `mise` tool install is partially broken here

`mise install -y` fails for `github:nsheaps/op-exec@0.1.26`:

```
HTTP status client error (403 Forbidden) for url
(https://api.github.com/repos/nsheaps/op-exec/releases?per_page=100)
{"message":"GitHub access is not enabled for this session. An org admin must
connect the Claude GitHub App for this organization."}
```

`github:`-backend mise tools cannot resolve because the releases API is
blocked. A stale `op-exec 0.1.17` from the image remains installed, so the pin
in `mise.toml` is **not** honoured in cloud sessions.

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

1. `op whoami` → authenticates as `SERVICE_ACCOUNT` (integration
   `BTDBO7KDGVBDNIKUKHYKUPIPGM`). **OK**
2. `op://Agent-Jack/ENVIRONMENT` is readable and carries `GITHUB_APP_ID`,
   `GITHUB_INSTALLATION_ID`, `GITHUB_APP_PRIVATE_KEY`. **OK**
3. Those fields hold **nested** `op://Agent-Jack/github--app--jack/...`
   references. Following them one more hop yields real values (App ID 7 chars,
   installation ID 9 chars, a 1674-byte PEM with a valid `BEGIN` header). **OK**
   (`op read` does _not_ dereference recursively — that is `op-exec`'s job, and
   `op-exec` is not on `PATH`; see §2.)
4. `github-app/bin/generate-token.sh` with those values → **BLOCKED**:

```
Token exchange failed (HTTP 403):
{"message":"Access to this GitHub API path is not permitted through this proxy."}
```

### Three distinct denial classes

Probing with the injected `GH_TOKEN` returns 403 for most paths, but for
**three different reasons**. Conflating them is misleading, because they are
separate policy knobs:

| Class                         | Denial message                                                                                    | Paths observed                                                     |
| ----------------------------- | ------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------ |
| **A — proxy path denylist**   | "Access to this GitHub API path is not permitted through this proxy."                             | `GET /app`, `POST /app/installations/{id}/access_tokens`           |
| **B — session GitHub access** | "GitHub access is not enabled for this session. An org admin must connect the Claude GitHub App…" | `GET /repos/nsheaps/ai-mktpl`, `GET /repos/nsheaps/ai-mktpl/pulls` |
| **C — session repo binding**  | "This GitHub API path is not available: sessions are bound to their configured repositories."     | `GET /installation/repositories`, `GET /users/jack-nsheaps[bot]`   |

Permitted: `GET /user` → 200, `GET /rate_limit` → 200.

Per `/root/.ccr/README.md`, a 403 from the proxy is an organization
egress-policy denial that must be reported rather than worked around.

### Consequences

- **No Jack installation token can be minted** (class A). The `github-app`
  SessionStart hook correctly detects missing credentials and skips; its data
  dir is empty — no `github-app.pem`, no `github-token`, no isolated `gh/` or
  `git/config`.
- **Commits cannot be authored as Jack.** Git identity in this session is
  `Claude <noreply@anthropic.com>`; `GIT_AUTHOR_*` / `GIT_COMMITTER_*` are
  unset and `GIT_CONFIG_GLOBAL` is not isolated.
- **The bot user ID cannot be resolved** (class C), so even a manual identity
  override is unsafe. The plugin's own BUG-7 guard covers exactly this case and
  deliberately refuses to guess:

  > Rather than silently produce miscredited commits, refuse to configure git
  > identity.

  That guard behaved correctly. **This report does not override it** — the
  accompanying commit is intentionally _not_ forged with a Jack identity.

- **The effective GitHub identity is `nsheaps`**, not Jack: both the injected
  `GH_TOKEN` and the `mcp__github__*` server resolve to user `nsheaps`
  (id 1282393). Repo reads/writes work only through the session's MCP server
  and git proxy, not through raw-token REST calls.

> **Important:** lifting class A alone would fix check 4 but **not** check 3.
> Authoring commits as Jack additionally requires resolving the bot user ID via
> `/users/<slug>[bot]`, which is blocked by class C. Both must be addressed.

## Recommended follow-ups

Tracked issues are linked inline; see also `.claude/rules/ongoing-issues.md`.

1. **Decide whether Jack-authored commits are in scope for cloud sessions.** If
   yes, org egress policy must permit **both** the App token-exchange path
   (class A) and `/users/<slug>[bot]` (class C). No client-side change can
   substitute for either. → [#756](https://github.com/nsheaps/ai-mktpl/issues/756)
2. **Make `github-app` fail loudly when credentials are configured but
   unreachable.** Concretely: when `github-app.ref` is set and token generation
   fails with a proxy 403, emit a `systemMessage` naming the blocked path, so
   the identity fallback is visible in-session. Today the hook logs and
   `exit 0`s (`hooks/scripts/github-token-init.sh`), so the session silently
   commits under a different identity. The `ref:`-set distinction is already
   available at that code path, so this is a small change.
   → [#757](https://github.com/nsheaps/ai-mktpl/issues/757)
3. **Do not rely on bare `op` / `op-exec` on `PATH` in hooks** — resolve them
   via `mise which` or an explicit install path, since mise is not activated in
   the agent Bash environment. This is a _how_, so per
   `.claude/rules/plugin-development.md` it belongs in the `1pass` plugin's
   skill, not only here. → [#758](https://github.com/nsheaps/ai-mktpl/issues/758)
4. **Pin `op-exec` to a non-`github:` backend** (or vendor it) so the
   `mise.toml` pin is honoured where the GitHub releases API is blocked.
   → [#759](https://github.com/nsheaps/ai-mktpl/issues/759)
5. **Re-test native SessionStart dispatch** (§2) by checking for a log entry
   with a resolved `event=SessionStart`. Relevant to
   [#745](https://github.com/nsheaps/ai-mktpl/issues/745).
