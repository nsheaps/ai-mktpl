# Usability Review — PR #266

**Score: 76/100**

The poc-shared-rules plugin has a well-structured README that covers the core use case clearly. The source reference format (`owner/repo@ref:/path`) is concise and consistent with GitHub Actions conventions, which lowers the learning curve for the target audience. The comparison table against `common-sense` is a genuine usability win — it makes the trade-offs explicit so a user can decide which plugin fits their project without guessing. The default settings file is particularly well done: every option has an inline comment, the format mirrors what users actually write in `plugins.settings.yaml`, and examples are concrete and copy-pasteable. Error messages in the hook script are specific and actionable — `hook_fail` calls include both the problem ("Failed to clone ${clone_url}") and a fix hint ("Check that the repository exists and is publicly accessible"), which is better than most plugins in this repo.

That said, several friction points hold the score below 90. First, the "poc-" prefix in both the plugin name and configuration key (`poc-shared-rules:`) will propagate into every project's `plugins.settings.yaml` and will require a find-and-replace migration when the plugin is promoted. The README calls this out as a proof-of-concept but does not tell users what to expect — will their config break? Will there be a migration path? Second, the `lib/` directory is not listed in the repo (only `hooks/` and the settings file appear), but the hook script sources `plugin-config-read.sh` and `hook-logging.sh` via `${CLAUDE_PLUGIN_ROOT}/lib/`. The README gives no indication of any prerequisites or whether those libraries are bundled vs symlinked, leaving a potential silent failure with no actionable message. Third, the "no sources configured" message in the hook (line 359) is plain informational text rather than a first-run onboarding prompt — a user who installs the plugin and sees nothing in their session output will not know they need to add configuration. Fourth, the recursive dependency feature (`.shared-rules.yaml`) has no worked example in the README showing the file format alongside the parent config, so it looks more complex than it is. Finally, the `alsoSyncToUser` option's effect on downstream session behavior (rules become available globally, not just for this project) is described but not warned about — enabling it silently changes behavior for every project the user opens.

Compared to `mise/README.md`, which separates Features, How It Works, Configuration, and a named Pattern section, the poc-shared-rules README merges installation into a short block and buries the caching behavior near the bottom. `common-sense/README.md` is simpler by nature (zero-config), so comparison is less meaningful there. The poc-shared-rules README is clearly better than common-sense's but not quite as polished as mise's, which names the behavioral pattern explicitly.

## Inline Comments

### plugins/poc-shared-rules/README.md:5
The PoC disclaimer is useful but incomplete. Users need to know whether existing configuration will be migrated or break when the plugin is promoted to `shared-rules`. Add a sentence: "Configuration key will change on promotion; plan to rename `poc-shared-rules:` to `shared-rules:` in your `plugins.settings.yaml`."

### plugins/poc-shared-rules/README.md:32
The Installation section shows how to enable the plugin but does not mention that `sources` must also be configured before anything happens. A new user who follows only this section will see a silent "no sources configured" log and wonder why nothing appeared. Add a note like: "After enabling, configure at least one source (see Configuration below) — the plugin takes no action until sources are defined."

### plugins/poc-shared-rules/README.md:61-72
The Recursive Dependencies section shows the `.shared-rules.yaml` format but gives no hint about where this file lives relative to the repo (inside the `path` directory being referenced). Add one sentence clarifying that `.shared-rules.yaml` must live at the root of the `path` directory specified in the source ref (e.g., at `plugins/common-sense/rules/.shared-rules.yaml`).

### plugins/poc-shared-rules/README.md:76
Caching behavior says "fetches the latest commits for the specified ref" but does not mention that pinning to a commit SHA effectively disables auto-update (the fetch is a no-op once the SHA is already present). This is an important behavioral difference for users who want stable rules vs always-latest rules.

### plugins/poc-shared-rules/README.md (missing section)
There is no "Troubleshooting" or "Requirements" section. The hook depends on `git` being available and optionally on `yq` or `python3` for config reading. A user on a minimal web session who lacks git will get a cryptic `hook_fail` with no guidance. Even a single-line callout — "Requires: git (for cloning), yq or python3 (for config parsing)" — would reduce support burden.

### plugins/poc-shared-rules/hooks/scripts/sync-rules.sh:359
The "no sources configured" message is logged via `hook_log`, which goes to stderr and `additionalContext`. It will not surface prominently to a first-time user who just enabled the plugin and is waiting to see it do something. Consider either elevating this to a more prominent warning or including it in `hook_respond` output so it appears in the session start message.

### plugins/poc-shared-rules/hooks/scripts/sync-rules.sh:174
The warning "is a real directory — not replacing; remove it manually" is logged via `hook_log` (stderr + accumulated text) but still returns 0 and continues. This silent skip could confuse users who renamed a rules directory and now wonder why the symlink wasn't updated. The message is technically correct but would benefit from a concrete path in the "remove it manually" instruction: "remove it manually: `rm -rf <link_path>`".

### plugins/poc-shared-rules/poc-shared-rules.settings.yaml:23
The `alsoSyncToUser` option description says "also sync to user-level ~/.claude/rules/" but does not warn that this affects ALL projects on the machine, not just the current one. A one-line warning here would prevent an easy misconfiguration: "Warning: enabling this makes rules available globally, not just in this project."
