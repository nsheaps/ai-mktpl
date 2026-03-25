# Security Review — PR #266

**Score: 42/100**

This plugin clones arbitrary remote git repositories and symlinks their contents directly into `.claude/rules/`, which Claude Code reads and executes as behavioral instructions. That trust boundary is the central security concern. Several specific issues compound the risk:

**1. Path traversal via user-supplied `_SRC_PATH` (HIGH — CWE-22).** The `_SRC_PATH` variable is extracted from user-supplied config (`owner/repo@ref:/path`) with only a leading `/` stripped (line 68: `_SRC_PATH="${_SRC_PATH#/}"`). There is no validation against `..` components. A value like `../../.ssh` or `../../home/user/.bashrc` would construct a `cache_dir`-relative path that escapes the intended rules directory. This path is then passed directly to `git sparse-checkout set` (lines 126–127, 153–154) and used to compute `rules_path` (line 253), which is then symlinked into `.claude/rules/`. An attacker who controls the config (e.g. via a compromised `plugins.settings.yaml` in a repo) could point the symlink at an arbitrary filesystem path.

**2. Unvalidated symlink name (`_SRC_NAME`) — directory escape in rules dir (HIGH — CWE-22).** The symlink name comes from the key in the YAML mapping (left of `=` in parsed output, line 62) or from `_SRC_PATH##*/` (line 92). It is used directly in `link_path="${rules_dir}/${name}"` (line 167) with no check for `/` or `..` in `name`. A name like `../../../.claude/settings.json` would place the symlink outside the rules directory entirely, potentially overwriting sensitive files.

**3. Recursive dependency fetched from arbitrary remote repos (HIGH — Supply Chain).** Lines 267–275 call `read_dependencies` on a `.shared-rules.yaml` file found inside the cloned repo (i.e. content fully controlled by the remote). The parsed dependency strings are passed back into `process_source` without any validation of owner, repo, ref, or path. This means a malicious or compromised remote repo can chain-pull from other arbitrary repos with no user confirmation. The depth limit of 10 (line 268) is the only guard, and it does not restrict the breadth (each node can pull many dependencies). This is an SSRF/supply-chain concern — a single trusted source can bootstrap an arbitrarily large transitive graph of untrusted repos.

**4. Unquoted `$ref` in git commands (MEDIUM — CWE-78).** In `fetch_into_cache`, the `$ref` variable is interpolated directly into `git ... --branch "$ref"` (line 137), `git ... checkout "$ref"` (line 122), and `git ... checkout "origin/${ref}"` (lines 123, 157). These are double-quoted so word splitting is not an issue, but git interprets some ref strings specially (e.g. refs that start with `-` can be treated as flags). A ref value of `-u /tmp/evil` or `--upload-pack=/tmp/evil` would be passed as git flags. There is no validation that `$ref` is a safe git ref name (alphanumeric, `/`, `.`, `_`, `-`).

**5. `cacheDir` override used without validation (MEDIUM — CWE-22).** The `CACHE_BASE` variable is set from user config (line 37). If an attacker sets this to a path outside the home directory (e.g. `/etc` or `/tmp/something`), the plugin will clone repos there and create symlinks relative to that path. Combined with issue #2 above, this can be chained to write symlinks in sensitive locations.

**6. `yq` expression injects user-supplied `$key` (LOW — CWE-78).** In `read_source_config` line 300, the yq expression uses string interpolation: `yq -r ".[\"${key}\"].sources[]..."`. `key` is set to `$PLUGIN_NAME` which is hardcoded (`"poc-shared-rules"`), so in practice this is not exploitable today. However, if this pattern is copy-pasted for a configurable plugin name, it would allow yq expression injection.

**7. No validation that cloned content is safe before symlinking (HIGH — Design).** The plugin symlinks a remote repo's directory directly into `.claude/rules/`. Claude Code reads `.md` files from that directory as behavioral instructions. There is no integrity check (no pinning by commit SHA, no signature verification). A branch like `main` can change at any time between sessions. An attacker who can push to the referenced branch (or compromise it) can inject arbitrary AI instructions into any project using this plugin.

**8. No credential handling found (POSITIVE).** No SSH keys, tokens, or passwords are used or logged. All clones use unauthenticated HTTPS. This limits the credential exposure surface.

**9. Temporary file for cycle detection is safe (POSITIVE).** `mktemp` at line 365 and a proper `trap` cleanup at line 366 are used correctly. No symlink race condition observed here.

**Summary:** The plugin's fundamental design — fetching and symlinking arbitrary remote content as AI rules — is an inherently high-trust operation. The implementation lacks input validation on path components and symlink names, which allows path traversal. Recursive dependency resolution from remote-controlled files provides a supply-chain vector. Git ref values are not sanitized against flag injection. For a PoC these are acceptable known risks, but they should be explicitly documented and mitigated before promotion to `shared-rules`.

---

## Inline Comments

### plugins/poc-shared-rules/hooks/scripts/sync-rules.sh:67–68
`_SRC_PATH` is stripped of its leading `/` but not validated for `..` components. A path like `../../.ssh` would survive this and be passed to `sparse-checkout` and used as the symlink target. Add: `if [[ "$_SRC_PATH" =~ (^|/)\.\.(/|$) ]]; then hook_fail ...; return 1; fi`

### plugins/poc-shared-rules/hooks/scripts/sync-rules.sh:62
`_SRC_NAME` (symlink name) comes from the left side of `=` in user config with no sanitization. A name containing `/` or `..` would allow directory traversal when constructing `link_path="${rules_dir}/${name}"` at line 167. Validate that `_SRC_NAME` contains only safe characters (`[a-zA-Z0-9._-]`).

### plugins/poc-shared-rules/hooks/scripts/sync-rules.sh:136–137
`$ref` is passed directly as `--branch "$ref"` to git. Git option injection is possible if `$ref` starts with `-`. Validate that `$ref` matches a safe ref pattern (e.g. `[a-zA-Z0-9._/-]+`) before use.

### plugins/poc-shared-rules/hooks/scripts/sync-rules.sh:201
`read_dependencies` parses a `.shared-rules.yaml` from the cloned repo — content fully controlled by the remote repository author. Parsed entries are passed without further validation into `process_source` at line 271. A malicious repo can use this to trigger clones of other arbitrary repos at session start. At minimum, this should be opt-in (disabled by default) and prominently documented as a trust escalation.

### plugins/poc-shared-rules/hooks/scripts/sync-rules.sh:37
`CACHE_BASE` is set from user-supplied `cacheDir` config with no path validation. Setting this to `/tmp` or `/etc` and combining with a traversal in `_SRC_NAME` could place symlinks in unexpected locations.

### plugins/poc-shared-rules/hooks/scripts/sync-rules.sh:268
The recursion depth limit of 10 prevents infinite loops but not wide dependency graphs. A single source can declare hundreds of dependencies, each cloning a separate repo. Consider also limiting total dependency count per run to prevent session-start denial-of-service.
