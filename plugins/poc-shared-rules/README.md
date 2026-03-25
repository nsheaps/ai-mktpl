# poc-shared-rules

Fetch and sync AI rules from git repository paths into `.claude/rules/`. References rules using a simple `name=owner/repo@ref:/path` format so you can share rulesets across projects without bundling them.

**Note:** This is a proof-of-concept plugin. It may be promoted to `shared-rules` in a future release.

## Requirements

- **git** — must be on `PATH`
- **yq** — required for reliable YAML parsing (installed automatically via `mise` in this repo)
- Network access to `github.com` (this plugin only supports GitHub repositories)

## What It Does

On session start, this plugin:

1. Reads the `sources` list from your configuration
2. Sparse-clones each referenced path from GitHub into a local cache (`~/.cache/claude-shared-rules/`)
3. Creates a symlink at `.claude/rules/<name>` pointing to the cached rules directory
4. Optionally resolves transitive dependencies from each directory's `.shared-rules.yaml` (requires `followDependencies: true`)

## Source Reference Format

Each source is a quoted string: `"name=owner/repo@ref:/path"`

- `name` — symlink name created in `.claude/rules/`
- `owner` — GitHub user or organization
- `repo` — repository name
- `ref` — branch, tag, or commit SHA
- `path` — directory path within the repository containing the rule files

## Installation

Enable via the marketplace in `.claude/settings.json`:

```json
{
  "enabledPlugins": {
    "poc-shared-rules@ai-mktpl": true
  }
}
```

## Configuration

Add sources in `.claude/plugins.settings.yaml`:

```yaml
poc-shared-rules:
  # Sources to fetch and symlink into .claude/rules/
  sources:
    - "common-sense=nsheaps/ai-mktpl@main:/plugins/common-sense/rules"
    - "team-rules=myorg/my-rules@v2.0.0:/rules"
    - "project-rules=myorg/my-rules@main:/.ai/rules"

  # Optional: also sync to user-level ~/.claude/rules/
  # WARNING: this is a global setting that affects ALL projects for your user account,
  # not just the current project. Use with care.
  alsoSyncToUser: false

  # Optional: override the local clone cache directory
  cacheDir: ""

  # Optional: follow .shared-rules.yaml dependency files in fetched rule directories.
  # Disabled by default for security — enabling this trusts remote repos to drive
  # additional git clones. Only enable for sources you fully control.
  followDependencies: false
```

## Recursive Dependencies

A rules directory can declare its own dependencies by including a `.shared-rules.yaml` file. You must set `followDependencies: true` for this to take effect.

```yaml
# rules/.shared-rules.yaml
dependencies:
  - "base=owner/repo@main:/base-rules"
  - "extra=owner/other-repo@v1.0.0:/extra-rules"
```

The plugin resolves these recursively (up to 10 levels deep) with cycle detection.

> **Security note:** Enabling `followDependencies` allows remote repository content to trigger additional git clones. Only use this with sources you trust completely.

## Caching

Clones are cached at `~/.cache/claude-shared-rules/<owner>/<repo>@<ref>/`. On each session start, the plugin fetches the latest commits for the specified ref, so your rules stay up to date automatically.

To force a clean fetch, delete the cache directory:

```bash
rm -rf ~/.cache/claude-shared-rules
```

## Troubleshooting

**No sources configured / hook does nothing**

- Check that your `plugins.settings.yaml` uses the key `poc-shared-rules:` with a nested `sources:` list
- Each source must be a quoted string in `"name=owner/repo@ref:/path"` format
- Verify `yq` is installed: `command -v yq`

**Clone fails / path not found**

- Confirm the repository exists and is publicly accessible on GitHub
- Confirm the `ref` (branch/tag) exists
- Confirm the `path` exists in the repository at that ref

**Stale symlinks after removing a source**

- Symlinks are not automatically removed when a source is deleted from config
- Manually remove the stale link: `rm ~/.claude/rules/<name>`

**Rules not appearing after session start**

- Check hook output via Ctrl+O in the Claude Code sidebar
- If `yq` is missing, sources may not be parsed — install it via `mise install yq`

## vs. common-sense

| Feature                     | common-sense           | poc-shared-rules                |
| --------------------------- | ---------------------- | ------------------------------- |
| Rules location              | Bundled in plugin      | Remote git repo                 |
| Multiple sources            | No                     | Yes                             |
| Custom ref (branch/tag/SHA) | No                     | Yes                             |
| Recursive dependencies      | No                     | Yes (opt-in)                    |
| Works offline               | Yes (after install)    | Requires git + network          |
| Update rules                | Requires plugin update | Fetches latest on session start |
| GitHub only                 | N/A                    | Yes (GitHub only)               |
