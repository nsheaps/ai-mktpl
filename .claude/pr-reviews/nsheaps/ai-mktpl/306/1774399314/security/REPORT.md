# Security Review — PR #306
Score: 62/100

## Summary

PR #306 introduces async shell-based hooks for PR state tracking. The scripts are well-structured and use `set -euo pipefail` in the entry point, pass API data through `jq` rather than raw shell parsing, and prefer quoted variables throughout. However, there are several notable security issues: git remote URLs are parsed with unvalidated `sed` patterns whose output is used directly in filesystem paths and API URLs (path traversal risk); user-supplied and API-derived values are interpolated into filenames without sanitization; the `check_interval` config value is used in a bash arithmetic expression without integer validation; cache files and directories are created without explicit restrictive permissions; and a TOCTOU race in the throttle logic allows duplicate concurrent API calls. None of these rise to remote code execution given the threat model (local user running a dev tool), but several can cause data written outside the intended directory or unintended API calls, and the terminal-output injection via raw PR content is a low-severity concern.

## Findings

### F1 — Path Traversal via Parsed Remote URL (Medium)
**File:** `plugins/github/hooks/scripts/lib/pr-discover.sh`, lines 88–100

`_pr_extract_owner_repo` extracts `_PR_OWNER` and `_PR_REPO` from the git remote URL using `sed` with no sanitization or character-class restriction. The captured groups allow `/`, `..`, `~`, and other filesystem-significant characters. Both values flow directly into the cache filename in `pr-state.sh`:

```
local cache_file="${_PR_STATE_CACHE_DIR}/${owner}_${repo}_${pr_number}.json"
```

A crafted remote URL such as `https://github.com/owner/../../../tmp/evil/x` would set `_PR_REPO` to `../../../tmp/evil/x` (after `.git` stripping), causing the cache file to be written at `~/.claude/plugin-cache/github/<slug>/pr-state/owner_../../../tmp/evil/x_N.json`, which resolves outside the cache tree. The same values are interpolated into the `gh api` URL path:

```
pr_number="$(gh api ${gh_hostname_flag} \
    "repos/${_PR_OWNER}/${_PR_REPO}/pulls?head=..."
```

Mitigation: validate that `_PR_OWNER` and `_PR_REPO` match `^[A-Za-z0-9_.-]+$` before use. Validate `pr_number` matches `^[0-9]+$`.

---

### F2 — `head_sha` from API Response Used in URL Without Validation (Low-Medium)
**File:** `plugins/github/hooks/scripts/lib/pr-state.sh`, lines 118–124

`head_sha` is extracted from the GitHub API JSON response via `jq -r '.head_sha // empty'` and immediately used in a subsequent API call:

```
checks_json="$(gh api ${gh_hostname_flag} \
    "repos/${owner}/${repo}/commits/${head_sha}/check-runs" \
    ...)"
```

A SHA returned by the API should be a 40-character hex string. If the API proxy or a MITM returns a crafted value (e.g., `../../actions/runners`), it becomes an unintended path in the GitHub API URL. While exploitability requires a compromised API endpoint, it is good practice to validate that `head_sha` matches `^[0-9a-f]{40}$` before use.

---

### F3 — Unquoted `$gh_hostname_flag` (Low)
**Files:** `plugins/github/hooks/scripts/lib/pr-discover.sh` line ~72; `plugins/github/hooks/scripts/lib/pr-state.sh` lines ~77, 83, 88, 94, 119

`gh_hostname_flag` is used unquoted in all `gh api` invocations:

```
gh api ${gh_hostname_flag} "repos/..."
```

The value is either empty or the literal string `--hostname github.com`, so word-splitting yields the correct two-word expansion and is not currently exploitable. However, if this variable's source ever changes, this pattern becomes a command-injection vector. The correct approach is to use a bash array: `local gh_flags=(); [[ ... ]] && gh_flags=(--hostname github.com); gh api "${gh_flags[@]}" ...`.

---

### F4 — `check_interval` Arithmetic Expansion Without Integer Validation (Low)
**File:** `plugins/github/hooks/scripts/pr-state-check.sh`, lines ~86–93

```bash
check_interval="$(plugin_get_config "prStateCheckInterval" "60")"
...
elapsed=$((now - last_check))
if [ "$elapsed" -lt "$check_interval" ]; then
```

`check_interval` comes from user YAML config without integer validation. The `[ "$elapsed" -lt "$check_interval" ]` test uses `-lt` which requires an integer; a non-integer value (e.g., `"abc"`) will cause a fatal error under `set -e`, exiting the hook early and disabling throttling for the session. More critically, while bash arithmetic `$((…))` does not execute shell commands, a value like `a[$(malicious_cmd)]` would be evaluated as an array subscript in some bash versions (indirect execution via `(( ))` arithmetic). The value should be validated with `[[ "$check_interval" =~ ^[0-9]+$ ]]` before use.

---

### F5 — Cache Files Created Without Explicit Permissions (Low-Medium)
**File:** `plugins/github/hooks/scripts/lib/pr-state.sh`, line ~43; `pr-state-check.sh` line ~62

```bash
mkdir -p "$_PR_STATE_CACHE_DIR"
...
echo "$new_state" > "$cache_file"
```

Neither the directory nor files are created with an explicit restrictive mode. The default umask determines permissions. On a shared system where `~/.claude/` is world-readable (or group-readable), PR metadata — including PR bodies, reviewer names, comment text, and CI results — would be readable by other users. Recommendation: `mkdir -p -m 700 "$_PR_STATE_CACHE_DIR"` or `umask 077` at the top of the script.

---

### F6 — TOCTOU Race in Throttle Logic (Low)
**File:** `plugins/github/hooks/scripts/pr-state-check.sh`, lines ~86–95

The throttle pattern reads `.last-check`, evaluates elapsed time, then writes the updated timestamp — a classic check-then-act race:

```bash
if [ -f "$last_check_file" ]; then
    last_check="$(cat "$last_check_file")"
    elapsed=$((now - last_check))
    if [ "$elapsed" -lt "$check_interval" ]; then exit 0; fi
fi
echo "$now" > "$last_check_file"
```

If multiple hook invocations run concurrently (e.g., a user triggers many tool uses in rapid succession in a multi-process setup), all can pass the throttle gate simultaneously, each making full API requests and potentially reporting duplicate change notifications. Mitigation: use `flock` for atomic read-update (`flock "$last_check_file" bash -c '...'`).

The same race applies in `pr_state_fetch_and_compare`: old state is read, API is called, new state is written — concurrent invocations can each read the same baseline and emit the same changes twice.

---

### F7 — Raw PR Content Interpolated into Change Strings (Low)
**File:** `plugins/github/hooks/scripts/lib/pr-state.sh`, lines ~178, 184 and throughout `_pr_state_diff`

PR titles, labels, and the first 100 characters of comment/review bodies from the GitHub API are interpolated directly into the `PR_STATE_CHANGES` array strings and echoed to stdout:

```bash
PR_STATE_CHANGES+=("PR title changed: '${old_title}' -> '${new_title}' on ...")
...
echo "  - ${change}"
```

A PR title containing terminal escape sequences (e.g., `\033[2J` to clear the terminal, or hyperlink sequences) would be emitted verbatim to the terminal. This does not allow command execution but can corrupt terminal state. Recommendation: strip or escape non-printable characters from API-derived values before including them in output. `jq`'s `@sh` or `@base64` filters could be used for sanitization, or the output could be passed through `cat -v`.

---

### F8 — `set -euo pipefail` Absent from Sourced Library Files (Informational)
**Files:** `plugins/github/hooks/scripts/lib/pr-state.sh` line 1; `plugins/github/hooks/scripts/lib/pr-discover.sh` line 1

The library files are sourced (not executed), so they inherit the entry point's `set -euo pipefail`. This is correct behavior. However, the absence of the directive in the library headers means if a future caller sources these libraries without strict mode, silent failure propagation becomes possible (e.g., a failed `git` command silently returning empty string). A comment noting this inherited dependency would help prevent future misuse.

---

### F9 — `project_slug` Safe; No Path Traversal (Informational — Positive Finding)
**File:** `plugins/github/hooks/scripts/pr-state-check.sh`, line ~60

```bash
project_slug="$(basename "$CLAUDE_PROJECT_DIR")"
```

`basename` correctly strips path components, so a `CLAUDE_PROJECT_DIR` of `/workspace/../../etc` would yield `etc` as the slug rather than traversing outside the cache root. This is correctly handled.

---

### F10 — No Validation That Discovered Sibling Directories Are Trustworthy (Low)
**File:** `plugins/github/hooks/scripts/lib/pr-discover.sh`, lines ~30–43

The multi-project discovery scans `$(dirname "$CLAUDE_PROJECT_DIR")/*/` for sibling `.git` repos. In a shared or adversarially constructed filesystem, a symlinked directory or an attacker-planted git repo in the parent directory could be discovered and have its remote URL parsed, potentially causing `gh api` calls for attacker-controlled repositories. This is a low-severity concern in the intended single-user workstation context but worth noting for web-session deployments on shared infrastructure.

## References

- `plugins/github/hooks/scripts/pr-state-check.sh` (entry point, throttle logic, cache resolution)
- `plugins/github/hooks/scripts/lib/pr-state.sh` (API fetching, cache write, diff logic)
- `plugins/github/hooks/scripts/lib/pr-discover.sh` (URL parsing, sibling discovery)
- `plugins/github/hooks/hooks.json` (hook registration)
- [CWE-22: Path Traversal](https://cwe.mitre.org/data/definitions/22.html)
- [CWE-190: Integer Overflow / Improper Input Validation in Arithmetic](https://cwe.mitre.org/data/definitions/190.html)
- [CWE-362: TOCTOU Race Condition](https://cwe.mitre.org/data/definitions/362.html)
- [CWE-116: Improper Encoding / Escaping of Output](https://cwe.mitre.org/data/definitions/116.html)
- [bash arithmetic injection via array subscript](https://www.google.com/search?q=bash+arithmetic+injection+array+subscript+security)
- [flock(1) man page — for atomic file locking in shell](https://man7.org/linux/man-pages/man1/flock.1.html)
