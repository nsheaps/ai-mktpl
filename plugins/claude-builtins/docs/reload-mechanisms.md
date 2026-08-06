# Reload mechanisms: can the model force `/reload-plugins` or `/reload-skills`?

Investigation output, produced with the [`extract-builtins`](../skills/extract-builtins/SKILL.md)
methodology (byte-offset slice → beautify → AST traversal; the obfuscated source
was never read directly).

## Binary provenance

Every claim below was recovered from a single build. Re-verify against a new
stamp after any binary update.

- claude version: **2.1.223**
- git sha: `4535f69721056abf01650c73ee8a91c69ba00838`
- build time: `2026-08-05T18:12:31Z`
- binary path: `/opt/claude-code/bin/claude` (Bun-compiled ELF)

## Question

Are there **any** mechanisms — including hidden ones — by which Claude (the
model/agent) can force `/reload-plugins` or `/reload-skills` to happen from
within a session, i.e. by emitting something rather than the user typing the
command?

## Answer: three reload triggers exist; none is model-invokable

| #   | Trigger                                                                                 | Scope                               | Who fires it                             | Model can invoke? |
| --- | --------------------------------------------------------------------------------------- | ----------------------------------- | ---------------------------------------- | ----------------- |
| 1   | Local slash commands `/reload-plugins`, `/reload-skills`                                | plugins / skills                    | the **user**, from the parsed input line | No                |
| 2   | SDK host control request `{subtype:"reload_plugins"\|"reload_skills"}` / `reinitialize` | plugins / skills                    | the **host app**, into the CLI           | No                |
| 3   | SessionStart hook returning `{"reloadSkills":true}`                                     | **skills only**, session start only | a **hook** at session start              | No                |

There is **no model-callable reload tool**. The only tool-shaped surface in the
relevant code is `ToolSearchTool`; nothing scans model output for a `/command`,
and no tool's `call` invokes the reload paths.

### 1. Local slash commands — user input only

Recovered command definitions and handlers:

- `/reload-plugins` — `rcb` (definition), `ecb` (handler). `type:"local"`,
  `supportsNonInteractive:!1`, `thinClientDispatch:"control-request"`,
  description "Activate pending plugin changes in the current session",
  `argumentHint:"[--force]"`.
- `/reload-skills` — `ocb` (definition), `ncb` (handler). `type:"local"`,
  `supportsNonInteractive:!0`, `thinClientDispatch:"post-text"`, description
  "Pick up skills added or changed on disk during this session".

`type:"local"` commands are dispatched from the **parsed user input line**, not
from model tokens. `ecb`'s local branch calls `c0e` (refreshActivePlugins);
`ncb` calls `nj()` (clear-skills-cache) then `ace()` (reload-skills) then
`$Q.emit()` (state-changed). No code path feeds model output into this
dispatcher, so the model emitting the literal text `/reload-plugins` does
nothing — it is just assistant text.

### 2. SDK host control requests — host → CLI, not CLI → self

The SDK `Query` client exposes `reloadPlugins()`, `reloadSkills()`, and
`reinitialize()`, which send `{subtype:"reload_plugins"|"reload_skills"}` /
`sdk_reinitialize` **into** the CLI. These are called by the **host
application** driving the SDK, not by the model. The CLI's own REPL control
receiver does not even handle those subtypes (its `default` branch returns
"REPL bridge does not handle control_request subtype: …"), so an in-session
agent cannot reach them.

### 3. SessionStart hook `reloadSkills:true` — skills only, start only

The SessionStart hook runner (`T3e`) checks each hook result for
`reloadSkills` and, if set, runs `nj(),ace(),$Q.emit()` and emits telemetry
`hook_session_start_reload_skills`. This is:

- **skills only** — there is no `reloadPlugins` field on this path;
- **SessionStart only** — the setup runner (`aNd`) has no `reloadSkills`
  handling, so it cannot be re-triggered mid-session;
- **hook-driven** — it fires from a hook's JSON output at session start, which
  the model does not control during a turn.

### Minified symbol map (from the AST traversal)

| Symbol                   | Meaning                                                                                                     |
| ------------------------ | ----------------------------------------------------------------------------------------------------------- |
| `rcb` / `ecb`            | `/reload-plugins` definition / call handler                                                                 |
| `ocb` / `ncb`            | `/reload-skills` definition / call handler                                                                  |
| `c0e`                    | refreshActivePlugins (clears plugin caches, `needsRefresh:!1`, bumps `mcp.pluginReconnectKey`, `$Q.emit()`) |
| `nj()`                   | clear-skills-cache                                                                                          |
| `ace()`                  | reload-skills                                                                                               |
| `$Q.emit()`              | state-changed emitter                                                                                       |
| `Uv()`                   | is-remote / SDK-mode check                                                                                  |
| `Cvn`                    | MCP cache-impact check (drives `--force` warning)                                                           |
| `b_p`                    | telemetry emitter (`tengu_reload_plugins_cache_impact`)                                                     |
| `T3e`                    | SessionStart hook runner                                                                                    |
| `ToolSearchTool` / `shn` | tool-definition template (only tool-shaped surface here)                                                    |

## Since no mechanism exists: giving the model the ability via a binary patch

This is the explicit process to add an **env-var-gated tool the model can call**
to force a reload, matching the binary-patching approach used in
`nsheaps/agents` and `nsheaps/claude-utils`. See the
[`binary-patching-methodology`](https://github.com/nsheaps/claude-utils) skills
there for the general framework; the steps below are specific to this feature.

### Step 0 — Version-pin

Patches are build-specific. Record the target binary's version/sha (Step 0 of
`extract-builtins`) and pin the patch to it. Re-derive anchors on every upgrade;
never assume offsets or minified names survive a bump.

### Step 1 — Discover anchors

With the extract pipeline, recover and AST-confirm the current names of:

- `c0e` (refreshActivePlugins) — the plugin-reload primitive;
- `nj` + `ace` + `$Q.emit` — the skill-reload primitives;
- `ToolSearchTool` / `shn` (schema `tNd`) — the tool-object template to mirror.

### Step 2 — Injection strategy

- **Skills-only, no patch needed:** prefer a **SessionStart hook** that returns
  `{"reloadSkills":true}`. This is a supported path and requires no binary
  change — but it only reloads _skills_, only at session start.
- **A mid-session, model-callable reload (plugins + skills):** add a new tool
  object mirroring `ToolSearchTool`, whose `call` runs
  `await c0e(setAppState)` (plugins) and/or `nj(); ace(); $Q.emit()` (skills),
  gated by `isEnabled: () => process.env.CLAUDE_ENABLE_RELOAD_TOOL === "1"` so it
  is inert unless explicitly turned on. Register it in the same tool list as
  `ToolSearchTool`.

  **Honest caveat:** adding a whole tool object is **not length-preserving**, so
  this is not pure in-place ELF byte-patching. It requires the extract →
  modify-source → `bun build --compile` rebuild route, not a hex patch.

### Step 3 — Validate

- With `CLAUDE_ENABLE_RELOAD_TOOL` unset: the tool is absent / inert; default
  behavior unchanged.
- With it set to `1`: the tool appears, and calling it clears the caches and
  emits state-changed (verify plugins/skills actually refresh on disk changes).
- Diff the tool list and telemetry against the unpatched binary to confirm no
  other surface changed.

### Step 4 — Distribute

Ship the rebuilt binary with a patch manifest: target version + sha, anchors
used, the injected tool's name/gate env var, and the validation results — so the
patch can be re-applied and audited on the next version.
