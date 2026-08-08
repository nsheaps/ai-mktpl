# Built-in slash command inventory & reproducibility cross-reference

This is the cross-reference the plugin is built from: the **docs-side** list of
built-in slash commands (discovered via the `claude-code-guide` agent against
the official Claude Code docs) merged with the **binary-side** command registry
(recovered by extracting strings from the compiled Claude Code binary
**v2.1.225** and grepping for the command-object declarations).

Each command object in the binary has the shape:

```js
{ type:"local"|"local-jsx"|"prompt", name:"X", aliases:[...],
  description:"...", source:"builtin", argumentHint:"...",
  isEnabled:()=>..., getPromptForCommand(e){...} }
```

The `type` field is what determines whether a command's behavior can be driven
from a plugin skill outside the CLI:

| `type`      | What it is                                                       | Extractable?                                  |
| ----------- | ---------------------------------------------------------------- | --------------------------------------------- |
| `prompt`    | Builds a prompt string sent to the model (`getPromptForCommand`) | **Yes** — extract the prompt, ship as a skill |
| `local`     | Client-side JS. Some compute over local data, many are TUI state | **Partially** — only the ones that compute    |
| `local-jsx` | Client-side React/JSX UI (pickers, toggles, dialogs, QR codes)   | **No** — pure terminal UI / host integration  |

"Extractable" here means: the built-in's prompt or computation can be recovered
verbatim from the binary and driven from a plugin skill using only local session
transcripts (`~/.claude/projects/**/*.jsonl`), git, the environment, and model
passes. Anything that toggles in-process TUI state, talks to Anthropic
account/billing backends, or drives a native host (desktop, mobile, IDE,
clipboard, QR) cannot be driven honestly outside the CLI and is **not faked**.

---

## Tier 1 — `type:"prompt"` builtins (reproducible as skills)

These send a constructed prompt to the model. The prompt text was extracted
verbatim from the binary; the plugin ships each as a skill + command wrapper.

| Command            | Binary description                                                      | Status in plugin |
| ------------------ | ----------------------------------------------------------------------- | ---------------- |
| `/insights`        | Generate a report analyzing your Claude Code sessions                   | **Built**        |
| `/init`            | Initialize a new CLAUDE.md file with codebase documentation             | Built (Tier 1)   |
| `/security-review` | Complete a security review of the pending changes on the current branch | Built (Tier 1)   |
| `/team-onboarding` | Help teammates ramp on Claude Code with a guide from your usage         | Built (Tier 1)   |

Notes:

- `/init` is declared `type:"prompt"` with a `get description(){…}` (it varies
  on `CLAUDE_CODE_NEW_INIT`), which is why it did not appear in a naive
  `name:"…",description:"…"` grep. It has two prompt variants — classic
  ("Initialize a new CLAUDE.md") and the newer skills/hooks-aware variant.
- `/security-review` is a no-argument `type:"prompt"` builtin. Its prompt drives
  a senior-security-engineer review of the current branch's pending changes
  against `origin/HEAD`, pulling the diff through four inline `git` bang-commands.
  (There is no built-in `/review` command; the working-tree-vs-PR review lives in
  the separate `/code-review` built-in skill — see Tier 3.)
- `/team-onboarding` first scans your usage over a window (default window days,
  session count, slash-command count, MCP-server count) and substitutes that
  into a prompt + guide template. The plugin reproduces the usage scan with a
  collector script and ships the extracted prompt/guide templates.

## Tier 2 — `type:"local"` computational builtins (reproducible as skills)

These do real computation over local data. Where built, they are reproduced by
scanning transcripts / git / env deterministically, then (where the builtin does)
an analysis pass.

| Command         | Aliases        | Binary description                                                    | Status in plugin                                                                                                                                                                                                                                                                    |
| --------------- | -------------- | --------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `/usage`        | `cost`,`stats` | Show session cost, plan usage, and what's contributing to your limits | **Partial** — the built-in is an Ink TUI over server-side plan/limit data (not reproducible); the plugin ships a local, approximate token scan + the binary's relative-weight unit, explicitly labeled as an approximation of the "what's contributing to your limits" section only |
| `/context`      | —              | Show current context usage                                            | _Not built_ — planned: transcript scan of the session's token composition                                                                                                                                                                                                           |
| `/recap`        | —              | Generate a one-line session recap now                                 | _Not built_ — planned: deterministic session summary + one-line model pass                                                                                                                                                                                                          |
| `/export`       | —              | Export the current conversation to a file or clipboard                | _Not built_ — planned: transcript → markdown/json file (clipboard documented)                                                                                                                                                                                                       |
| `/status`       | —              | Show version, model, account, API connectivity, and tool statuses     | _Not built_ — planned: version/env/git/tool availability locally (account partial)                                                                                                                                                                                                  |
| `/diff`         | —              | View uncommitted changes and per-turn diffs                           | _Not built_ — planned: `git diff` + per-turn file edits from the transcript                                                                                                                                                                                                         |
| `/skill-doctor` | —              | Show which loaded skills are unused and costing context               | _Not built_ — planned: loaded skills vs. skill invocations in the transcript                                                                                                                                                                                                        |

Caveat on `/status`: version, model, git, tool availability, and env are fully
local. **Account identity and live API connectivity** require the Anthropic
backend and cannot be reproduced offline — the skill would report those as
"unavailable (requires built-in auth)" rather than inventing them.

## Tier 3 — built-in programmatic **skills / workflows** (separate registry)

The docs list these under "Programmatic (Skill)" / "(Workflow)". They are **not**
in the slash-command object registry above — they are built-in _skills_, which
is why they don't appear as `type:"prompt"` command objects. They are large and
self-contained (their own multi-step procedures and, for `/deep-research`, a
workflow). Prompts are extractable but each is a project of its own; they are
**out of scope** for this plugin's first pass and listed here for completeness.

`/code-review` · `/simplify` · `/verify` · `/deep-research`
(workflow) · `/loop` · `/batch` · `/doctor` · `/dataviz` · `/design-sync` ·
`/claude-api` · `/fewer-permission-prompts`

(`/security-review` is also a built-in skill in this group, but it is a
no-argument `type:"prompt"` builtin whose prompt this plugin extracts verbatim —
so it is covered above in Tier 1 rather than left here as out-of-scope.)

## Tier 4 — client-side TUI state (NOT reproducible; not faked)

`type:"local-jsx"` or state-only `type:"local"`. These change in-process
terminal UI or session flags. There is no artifact to compute — reproducing them
outside the running client is meaningless.

`/clear` · `/compact` · `/theme` · `/color` · `/focus` · `/brief` · `/tui` ·
`/scroll-speed` · `/effort` · `/model` · `/config` (`settings`) · `/voice` ·
`/radio` · `/rename` (`name`) · `/fork` · `/branch` · `/cd` · `/plan` · `/copy` ·
`/background` (`bg`) · `/autocompact` · `/goal` · `/advisor` · `/help` ·
`/artifacts` · `/wellbeing` · `/powerup` · `/keybindings` · `/resume` ·
`/add-dir` · `/autofix-pr` · `/subtask` · `/tasks` (`bashes`) · `/loops` ·
`/workflows` · `/daemon` · `/btw` · `/fast` · `/pause-memory` · `/rewind`

## Tier 5 — auth / account / external / host / setup (NOT reproducible; not faked)

Require the Anthropic account/billing backend, a native host app, an external
service, or a device flow. Cannot be honestly reproduced from local data.

`/login` · `/logout` · `/upgrade` · `/usage-credits` · `/extra-usage`
(renamed → `/usage-credits`) · `/stickers` · `/passes` · `/feedback` · `/bug` ·
`/privacy-settings` · `/design` · `/design-consent` · `/design-revoke` ·
`/design-login` · `/mcp` · `/plugin` (`plugins`,`marketplace`) · `/permissions`
(`allowed-tools`) · `/hooks` · `/memory` · `/skills` · `/reload-plugins` ·
`/reload-skills` · `/ide` · `/desktop` (`app`) · `/mobile` (`ios`,`android`) ·
`/teleport` · `/session` (`remote`) · `/remote-env` · `/install` ·
`/install-github-app` · `/install-slack-app` · `/web-setup` · `/setup-bedrock` ·
`/setup-vertex` · `/heapdump` · `/version` · `/update` (`restart`) · `/stop` ·
`/import` · `/terminal-setup` · `/chrome` · `/remote-control` · `/exit` ·
`/debug` · `/rate-limit-options` · `/pro-trial-expired` · `/__remote-workflow` ·
`/workflow-launch-exec` · `/auto-mode-setup`

---

## Method notes

- Binary: Bun-compiled ELF, v2.1.225. `strings` dump (~37 MB) split into 520
  chunks; command objects located by grepping for
  `type:"(local|local-jsx|prompt)",name:"…"`. 102 command objects found.
- `/cost` and `/stats` are aliases of `/usage`; `/name` of `/rename`; `/bg` of
  `/background`; `/settings` of `/config`; etc. Aliases are noted inline, not
  double-counted.
- `mcp__…` is a dynamic tool prefix, not a command.
- `/pr-comments` had zero hits in this build (removed/renamed upstream).
- Some objects appear as **both** a `type:"local"` and a `type:"local-jsx"`
  entry (e.g. `usage`, `stop`, `rename`, `effort`, `color`, `skill-doctor`,
  `mcp`, `import`): the client picks the interactive JSX form on a TTY and the
  non-interactive `local` form otherwise. That does not change the tier.
