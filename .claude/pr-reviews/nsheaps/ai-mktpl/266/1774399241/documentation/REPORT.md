# Documentation Review — PR #266

**Score: 82/100**

The poc-shared-rules plugin has strong documentation for its complexity level. The README covers every meaningful user-facing concern: what the plugin does, the source reference format, installation, configuration (with real working examples), recursive dependency behavior, caching semantics, and a comparison table against the sibling `common-sense` plugin. The comparison table is a standout addition — it gives users exactly the context they need to choose between the two plugins. The `plugin.json` description is unusually informative; it concisely states the format syntax in the description field itself (`Sources are YAML mappings { name: 'owner/repo@ref:/path' }`), which aids marketplace discoverability. Keywords are accurate and well-chosen (`rules`, `shared`, `behavior`, `best-practices`, `session-start`, `git`, `remote`).

The default settings file (`poc-shared-rules.settings.yaml`) is exemplary: every key has an inline comment explaining its purpose, the allowed values, and their default. This is a noticeably higher quality than most plugins in the repo.

The `sync-rules.sh` script has a clear file-level header that mirrors the README's configuration section, making it self-contained for contributors reading the script directly. Function headers are present on all non-trivial functions and accurately describe their arguments and output format. Inline comments on complex git operations (sparse-checkout fallback chains, treeless clone filter) explain the "why" rather than just the "what". The `read_dependencies` function includes a critical NOTE about the python3 fallback limitation, which is exactly the kind of gotcha that prevents future confusion.

Gaps holding it back from a higher score: (1) There is no CHANGELOG or version history — the plugin is at `0.0.1` but the PR has no record of initial decisions or known limitations. (2) The README's "Note: This is a proof-of-concept" warning appears only briefly at the top without elaborating on what known limitations or rough edges exist. (3) The `hooks/hooks.json` `description` field documents the hook itself but there is no comment or documentation about the 60-second timeout choice and whether it may need tuning for large dependency graphs. (4) The legacy format in `parse_source_ref` (lines 75-94) is documented in the function header comment but not in the README — users who hand-write `.shared-rules.yaml` files may encounter it without warning. (5) The `alsoSyncToUser` setting description in the README says "Optional: also sync to user-level ~/.claude/rules/" but doesn't explain the security/scope implications of making project rules available globally.

Compared to the `1pass` README (the strongest comparator in the repo), poc-shared-rules matches it in depth and surpasses it in settings file quality. It falls slightly short in that `1pass` explicitly documents the "local sessions do nothing" behavior and explains the pattern for contributors; poc-shared-rules doesn't address what happens if git is unavailable or the network is unreachable (the hook will fail, but this is not mentioned).

## Inline Comments

### plugins/poc-shared-rules/README.md:5
The PoC disclaimer ("This is a proof-of-concept plugin. It may be promoted to `shared-rules` in a future release.") doesn't tell users what limitations to expect while it is in PoC state. Consider expanding: what is known to be rough, what use cases are not yet supported, or what stability guarantees (if any) apply.

### plugins/poc-shared-rules/README.md:72
"up to 10 levels deep" — the depth limit is mentioned but there is no guidance on what a user should do if they hit it (flatten the dependency tree, etc.). One sentence of troubleshooting guidance here would help.

### plugins/poc-shared-rules/README.md:76
The caching section says the plugin "fetches the latest commits for the specified ref" on each session start, but it doesn't mention that if the network is unavailable the hook will fail loudly. A note like "If git is unavailable, the hook will report an error; existing cached clones are not used as a fallback" would set accurate expectations.

### plugins/poc-shared-rules/README.md (missing section)
The README has no troubleshooting section. Given that git sparse-checkout, symlink creation, and YAML parsing can all fail in distinct ways, a brief "Troubleshooting" section (e.g., stale symlinks pointing to deleted cache entries, yq vs python3 fallback, cache permission issues) would be consistent with the pattern set by `1pass/README.md` and `environment-setup-and-maintenance.md`.

### plugins/poc-shared-rules/hooks/scripts/sync-rules.sh:49
The legacy format comment says `"owner/repo/path@ref [as name]"` but the code at lines 83-93 parses `owner/repo` (two path segments) and treats everything after that as `_SRC_PATH`. If a user actually writes the legacy format, the behavior is non-obvious. The comment should either document this precisely or link to a test/example.

### plugins/poc-shared-rules/hooks/scripts/sync-rules.sh:192
The NOTE about python3 fallback only handling string format is important but easy to miss buried in the function. Consider surfacing this limitation in the README's "Recursive Dependencies" section as a dependency note (e.g., "Mapping-format dependencies in `.shared-rules.yaml` require `yq`; the python3 fallback only supports the legacy string format.").

### plugins/poc-shared-rules/hooks/hooks.json:11
The 60-second timeout is hardcoded with no comment explaining the rationale. For large dependency graphs (multiple repos, deep recursive dependencies), this could be insufficient. A comment in `hooks.json` or documentation in the README explaining why 60s was chosen (or that users can override it) would help operators tune for their use case.

### plugins/poc-shared-rules/poc-shared-rules.settings.yaml:20-22
The `alsoSyncToUser` setting comment explains the mechanical behavior well but omits the scope/security implication: rules synced to `~/.claude/rules/` affect ALL projects using Claude Code for that user, not just the current project. This side-effect should be noted explicitly.
