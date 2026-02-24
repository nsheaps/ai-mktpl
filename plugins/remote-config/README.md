# remote-config

Sync an upstream Claude config repo on session start.

## What It Does

On every `SessionStart`, pulls the latest from a configured git repo into `~/.claude-remote/`. Reports the update status so you know what version of your config is active.

## Configuration

Create `~/.claude/settings.remote-config.yaml`:

```yaml
# Required: URL of the upstream config repo
upstream: https://github.com/nsheaps/.claude.git

# Optional: show commit titles since last update (default: false)
verbose: true
```

### Environment Variable Override

Set `CLAUDE_REMOTE_UPSTREAM` to override the config file's `upstream` value:

```bash
export CLAUDE_REMOTE_UPSTREAM=https://github.com/nsheaps/.claude.git
```

## Behavior

### On Session Start

1. Reads config from `~/.claude/settings.remote-config.yaml` (or `CLAUDE_REMOTE_UPSTREAM` env var)
2. If `~/.claude-remote/` doesn't exist: clones the repo
3. If it exists: runs `git pull --ff-only`
4. Reports status:

**Clean update:**

```
[remote-config] Updated: abc1234 → v1.2.0 (def5678)
[remote-config] Changes:                          # only if verbose: true
  def5678 feat: add new agent definition
  abc1234 fix: correct hook path
```

**Already up to date:**

```
[remote-config] Up to date: v1.2.0 (abc1234)
```

**Dirty repo (conflicts or uncommitted changes):**

```
[remote-config] Error: Cannot update ~/.claude-remote cleanly
[remote-config] Suggest: cd ~/.claude-remote && git status
[remote-config] Claude could fix this — reset to origin and re-pull
```

### Status Format

- If HEAD is tagged: `tag (short-sha)` (e.g., `v1.2.0 (abc1234)`)
- If not tagged: `short-sha` (e.g., `abc1234`)
- If verbose: commit titles since last update, most recent last

## Installation

```bash
claude plugin install "remote-config@nsheaps-claude-plugins" --scope user
```

Then create the config file:

```bash
cat > ~/.claude/settings.remote-config.yaml << 'EOF'
upstream: https://github.com/nsheaps/.claude.git
verbose: false
EOF
```

## References

- [Claude Code Plugins](https://code.claude.com/docs/en/plugins)
- [Claude Code Hooks](https://code.claude.com/docs/en/hooks)
