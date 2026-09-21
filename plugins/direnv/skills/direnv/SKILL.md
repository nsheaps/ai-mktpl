---
name: direnv
description: >
  Use this skill when the user asks about managing per-directory environment
  variables with direnv, working with .envrc files, debugging why direnv env
  vars aren't appearing in a Bash tool call, or manually reproducing what the
  direnv plugin's SessionStart/PreToolUse hooks do. Also use when encountering
  "direnv: error .envrc is blocked" or missing project env vars that should
  come from an .envrc.
  <example>why isn't DATABASE_URL from .envrc showing up in Bash?</example>
  <example>the direnv hook didn't run, set up direnv manually</example>
  <example>I just added a new .envrc, why hasn't it loaded?</example>
---

# direnv - Per-Directory Environment Loader

[direnv](https://direnv.net) loads environment variables from a project's
`.envrc` file when you `cd` into it, and unloads them when you leave. This
skill covers both **normal direnv usage** and **how the `direnv` plugin wires
it into a Claude Code session** (for manual reproduction when a hook didn't
run).

## Quick Reference: Normal direnv Usage

### `.envrc` basics

```bash
# .envrc
export DATABASE_URL="postgres://localhost/mydb"
export NODE_ENV="development"

# Load a .env file
dotenv

# Add to PATH
PATH_add ./bin

# Use a specific tool version manager stdlib function
use node 22
```

### Core commands

| Command                 | Description                                                                                            |
| ----------------------- | ------------------------------------------------------------------------------------------------------ |
| `direnv allow [.envrc]` | Trust an `.envrc` so it's allowed to load                                                              |
| `direnv deny [.envrc]`  | Revoke trust                                                                                           |
| `direnv reload`         | Force a reload in the current shell (interactive)                                                      |
| `direnv export bash`    | Print the export/unset diff for the current dir as bash statements (does NOT modify the current shell) |
| `direnv status`         | Show current direnv state and loaded `.envrc`                                                          |
| `direnv edit [.envrc]`  | Edit and auto-allow in one step                                                                        |

### Why direnv might not load

1. **Not allowed yet**: a fresh or modified `.envrc` must be explicitly trusted: `direnv allow`
2. **No shell hook installed**: interactively, direnv requires `eval "$(direnv hook bash)"` in your shell rc file. **This Claude Code plugin intentionally does NOT install that hook** — see below.

## How This Plugin Wires direnv Into a Session

Unlike normal interactive usage, this plugin does not install `direnv hook
bash`. Instead:

1. `hooks/scripts/install-direnv.sh` (SessionStart) installs direnv if
   needed, runs `direnv allow` on the project's `.envrc`, then runs
   `direnv export bash` **once** and writes the output as static
   `export`/`unset` statements to `$CLAUDE_PLUGIN_DATA/direnv-env`.
2. That file is sourced (once) from `CLAUDE_ENV_FILE`, so every `Bash` tool
   call picks it up.
3. `hooks/scripts/direnv-check.sh` (PreToolUse, matcher `Bash`) checks
   (debounced) whether the `.envrc` fingerprint changed since the last
   export, and if so, re-runs `direnv export bash` and rewrites
   `direnv-env` in place.

See the plugin's `README.md` for the full rationale (avoiding
eval-injection and per-command stderr/stdout pollution from the ambient
shell hook).

## Manually Reproducing the Plugin's Setup

If the SessionStart hook did not run (plugin disabled, manual shell,
teammate started without hooks), reproduce it by hand:

```bash
CLAUDE_PLUGIN_DATA="${CLAUDE_PLUGIN_DATA:-$HOME/.claude/plugins/data/direnv-ai-mktpl}"
mkdir -p "$CLAUDE_PLUGIN_DATA"

# 1. Ensure direnv is installed (or use your own: brew install direnv)
command -v direnv >/dev/null || echo "install direnv first"

# 2. Allow the .envrc (required before export will produce anything)
direnv allow "${CLAUDE_PROJECT_DIR:-.}/.envrc"

# 3. Compute the diff once (static — not a live hook)
(cd "${CLAUDE_PROJECT_DIR:-.}" && direnv export bash) > "$CLAUDE_PLUGIN_DATA/direnv-env"

# 4. Wire it into CLAUDE_ENV_FILE (idempotent — check before appending)
if [[ -n "${CLAUDE_ENV_FILE:-}" ]] && ! grep -qF "$CLAUDE_PLUGIN_DATA/direnv-env" "$CLAUDE_ENV_FILE" 2>/dev/null; then
  echo "source \"$CLAUDE_PLUGIN_DATA/direnv-env\"" >> "$CLAUDE_ENV_FILE"
fi

# In the current shell (outside a fresh Bash tool call), source it directly:
source "$CLAUDE_PLUGIN_DATA/direnv-env"
```

## Verify

```bash
# Confirm the runtime file has content beyond the header comment
grep -v '^#' "$CLAUDE_PLUGIN_DATA/direnv-env"

# Confirm a fresh Bash call sees the vars (they come from CLAUDE_ENV_FILE)
echo "${DATABASE_URL:+set}"
```

## Troubleshooting

| Symptom                                               | Likely cause / fix                                                                                                                                                                                                                                          |
| ----------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Vars missing even though `.envrc` exists              | Not yet allowed — run `direnv allow`, then re-run the SessionStart hook (or Step 3 above)                                                                                                                                                                   |
| Vars still stale after editing `.envrc`               | PreToolUse debounce window not yet elapsed (default 2s, `checkIntervalSeconds`), or the edited `.envrc` is not the nearest one to the resolved target directory                                                                                             |
| New nested `.envrc` (in a subdirectory) not picked up | The `PreToolUse` hook resolves the target directory from a leading `cd` in the Bash command; without one it always checks `$CLAUDE_PROJECT_DIR`'s ancestor chain. Add an explicit `cd <dir> &&` prefix, or manually re-run Step 3 above from that directory |
| `direnv: error .envrc is blocked`                     | Run `direnv allow <path-to-.envrc>`                                                                                                                                                                                                                         |

## Related

- Plugin source: `hooks/scripts/install-direnv.sh`, `hooks/scripts/direnv-check.sh`, `lib/direnv-export.sh`
- **[mise](../../mise)** plugin — same "static export, no shell hook" pattern for tool version management
