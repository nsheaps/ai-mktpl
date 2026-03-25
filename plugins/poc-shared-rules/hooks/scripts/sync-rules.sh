#!/usr/bin/env bash
# sync-rules.sh — SessionStart hook for poc-shared-rules plugin
#
# Fetches rules from git repository paths and symlinks them into
# .claude/rules/. Sources are configured as quoted strings in plugins.settings.yaml:
#
#   sources:
#     - "common-sense=nsheaps/ai-mktpl@main:/plugins/common-sense/rules"
#     - "my-rules=myorg/my-rules@v2.0.0:/rules"
#
# Format: "name=owner/repo@ref:/path"
#   name  — symlink name under .claude/rules/
#   owner — GitHub organization or user
#   repo  — repository name
#   ref   — branch, tag, or commit SHA
#   path  — directory path within the repository
#
# Supports recursive dependency resolution: each fetched rules directory may
# contain a .shared-rules.yaml file listing additional sources in the same
# "name=owner/repo@ref:/path" format. Requires followDependencies: true.
#
# Config keys (via plugins.settings.yaml under 'poc-shared-rules:'):
#   sources             — array of "name=owner/repo@ref:/path" strings
#   alsoSyncToUser      — true/false: also symlink into ~/.claude/rules/
#                         WARNING: affects all projects for this user globally
#   cacheDir            — override cache directory (default: ~/.cache/claude-shared-rules)
#   followDependencies  — true/false: resolve .shared-rules.yaml in fetched dirs (default: false)
set -euo pipefail

PLUGIN_NAME="poc-shared-rules"

# shellcheck source=../../lib/plugin-config-read.sh
source "${CLAUDE_PLUGIN_ROOT}/lib/plugin-config-read.sh"

# shellcheck source=../../lib/hook-logging.sh
source "${CLAUDE_PLUGIN_ROOT}/lib/hook-logging.sh"

# --- Config ---

if ! plugin_is_enabled; then
  hook_log "plugin disabled — skipping"
  hook_respond
  exit 0
fi

ALSO_SYNC_TO_USER="$(plugin_get_config "alsoSyncToUser" "false")"
CACHE_DIR_OVERRIDE="$(plugin_get_config "cacheDir" "")"
FOLLOW_DEPENDENCIES="$(plugin_get_config "followDependencies" "false")"
DEFAULT_CACHE_DIR="${HOME}/.cache/claude-shared-rules"
CACHE_BASE="${CACHE_DIR_OVERRIDE:-${DEFAULT_CACHE_DIR}}"

PROJECT_RULES_DIR="${CLAUDE_PROJECT_DIR:-.}/.claude/rules"
USER_RULES_DIR="${HOME}/.claude/rules"

# Temp file used for cycle detection across the full recursive traversal
VISITED_FILE=""

# --- Parsing ---

# Parse a source string into component variables.
# Input: "name=owner/repo@ref:/path"
# Output (sets globals): _SRC_OWNER _SRC_REPO _SRC_PATH _SRC_REF _SRC_NAME
# IMPORTANT: This function sets global _SRC_* variables as its output mechanism.
# Do not call from a subshell — the globals will not be visible to the caller.
# Returns: 0 on success, 1 on validation failure (prints error to stderr).
parse_source_ref() {
  local ref_str="$1"

  _SRC_NAME=""
  _SRC_OWNER=""
  _SRC_REPO=""
  _SRC_PATH=""
  _SRC_REF=""

  if [[ "$ref_str" != *"="* ]]; then
    hook_fail "parse-error" \
      "Invalid source format: '${ref_str}'" \
      "Use format: \"name=owner/repo@ref:/path\""
    return 1
  fi

  # Format: name=owner/repo@ref:/path
  _SRC_NAME="${ref_str%%=*}"
  local value="${ref_str#*=}"

  # Split owner/repo@ref:/path
  local repo_ref="${value%%:*}"  # owner/repo@ref
  _SRC_PATH="${value#*:}"        # /path (may have leading /)
  _SRC_PATH="${_SRC_PATH#/}"     # strip leading /

  # Split owner/repo@ref
  _SRC_REF="${repo_ref##*@}"
  local owner_repo="${repo_ref%@*}"
  _SRC_OWNER="${owner_repo%%/*}"
  _SRC_REPO="${owner_repo#*/}"

  # --- Security validation ---

  # Reject symlink names containing path separators or traversal
  if [[ "$_SRC_NAME" == *"/"* ]] || [[ "$_SRC_NAME" == *".."* ]] || [[ -z "$_SRC_NAME" ]]; then
    hook_fail "invalid-name" \
      "Source name '${_SRC_NAME}' is invalid (must not contain / or ..)" \
      "Use a simple alphanumeric name like 'my-rules'"
    return 1
  fi

  # Reject paths containing traversal sequences
  if [[ "$_SRC_PATH" == *".."* ]]; then
    hook_fail "invalid-path" \
      "Path '${_SRC_PATH}' contains '..' traversal — rejected for security" \
      "Use a direct path like 'plugins/common-sense/rules'"
    return 1
  fi

  # Reject refs starting with '-' (would be interpreted as a git flag)
  if [[ "$_SRC_REF" == -* ]] || [[ -z "$_SRC_REF" ]]; then
    hook_fail "invalid-ref" \
      "Ref '${_SRC_REF}' is invalid (must not start with '-')" \
      "Use a branch name, tag, or commit SHA"
    return 1
  fi

  # Validate owner and repo are non-empty
  if [[ -z "$_SRC_OWNER" ]] || [[ -z "$_SRC_REPO" ]]; then
    hook_fail "parse-error" \
      "Could not parse owner/repo from '${value}'" \
      "Use format: \"name=owner/repo@ref:/path\""
    return 1
  fi
}

# --- Cache management ---

# Return the cache directory for a given owner/repo/ref.
get_cache_dir() {
  local owner="$1" repo="$2" ref="$3"
  # Replace / in ref (for branch names like feature/foo)
  local ref_safe="${ref//\//_}"
  echo "${CACHE_BASE}/${owner}/${repo}@${ref_safe}"
}

# Sparse-clone or update a git repo into the cache.
# Args: owner repo ref path
fetch_into_cache() {
  local owner="$1" repo="$2" ref="$3" path="$4"
  local cache_dir clone_url
  cache_dir="$(get_cache_dir "$owner" "$repo" "$ref")"
  clone_url="https://github.com/${owner}/${repo}.git"

  if [ -d "${cache_dir}/.git" ]; then
    hook_log "updating cache: ${owner}/${repo}@${ref}"
    # Fetch the specific ref and reset to it
    if ! git -C "$cache_dir" fetch origin --depth=1 "$ref" 2>/dev/null; then
      git -C "$cache_dir" fetch origin --depth=1 2>/dev/null || true
    fi
    git -C "$cache_dir" checkout FETCH_HEAD 2>/dev/null \
      || git -C "$cache_dir" checkout "$ref" 2>/dev/null \
      || git -C "$cache_dir" checkout "origin/${ref}" 2>/dev/null \
      || true
    # Ensure the requested path is included in sparse-checkout (may differ from initial clone)
    git -C "$cache_dir" sparse-checkout add "/${path}" 2>/dev/null \
      || git -C "$cache_dir" sparse-checkout add "$path" 2>/dev/null \
      || true
    git -C "$cache_dir" checkout 2>/dev/null || true
  else
    hook_log "cloning: ${owner}/${repo}@${ref}"
    mkdir -p "$(dirname "$cache_dir")"

    # Clone with treeless filter (no blob downloads until checkout)
    local clone_ok=false
    if git clone --depth=1 --filter=blob:none --no-checkout \
        --branch "$ref" "$clone_url" "$cache_dir" 2>/dev/null; then
      clone_ok=true
    elif git clone --depth=1 --filter=blob:none --no-checkout \
        "$clone_url" "$cache_dir" 2>/dev/null; then
      clone_ok=true
    fi

    if [ "$clone_ok" = "false" ]; then
      hook_fail "git-clone" \
        "Failed to clone ${clone_url}" \
        "Check that the repository exists and is publicly accessible"
      return 1
    fi

    # Non-cone sparse checkout: supports arbitrary sub-paths
    git -C "$cache_dir" sparse-checkout init --no-cone 2>/dev/null || true
    git -C "$cache_dir" sparse-checkout set "/${path}" 2>/dev/null \
      || git -C "$cache_dir" sparse-checkout set "$path" 2>/dev/null \
      || true
    git -C "$cache_dir" checkout 2>/dev/null \
      || git -C "$cache_dir" checkout "origin/${ref}" 2>/dev/null \
      || true
  fi
}

# --- Symlink helpers ---

# Create (or replace) a symlink at rules_dir/name -> target.
setup_symlink() {
  local target="$1" rules_dir="$2" name="$3"
  local link_path="${rules_dir}/${name}"

  mkdir -p "$rules_dir"

  if [ -L "$link_path" ]; then
    rm -f "$link_path"
  elif [ -d "$link_path" ]; then
    hook_log "WARNING: ${link_path} is a real directory — not replacing; remove it manually"
    return 0
  fi

  if ! ln -s "$target" "$link_path"; then
    hook_fail "symlink" \
      "Failed to create symlink ${link_path} -> ${target}" \
      "Check directory permissions for ${rules_dir}"
    return 1
  fi
  hook_log "linked ${link_path} -> ${target}"
}

# --- Dependency reading ---

# Read .shared-rules.yaml from a rules directory and print dependencies.
# Output: one "name=owner/repo@ref:/path" entry per line.
# NOTE: yq is required; if unavailable, dependencies are silently skipped.
# NOTE: The python3 fallback only handles string format; mapping format requires yq.
read_dependencies() {
  local rules_dir="$1"
  local deps_file="${rules_dir}/.shared-rules.yaml"

  [ -f "$deps_file" ] || return 0

  if command -v yq &>/dev/null; then
    # Handle both string and mapping entries
    yq -r '.dependencies[]? // empty | if type == "object" then to_entries[] | .key + "=" + .value else . end' "$deps_file" 2>/dev/null || true
  elif command -v python3 &>/dev/null; then
    python3 - "$deps_file" <<'EOF'
import sys, re
path = sys.argv[1]
in_deps = False
with open(path) as f:
    for line in f:
        if re.match(r'^dependencies\s*:', line):
            in_deps = True
            continue
        if in_deps:
            m = re.match(r'^\s+-\s+"?([^"#\n]+)"?', line)
            if m:
                print(m.group(1).strip())
            elif re.match(r'^\S', line):
                break
EOF
  else
    hook_log "WARNING: neither yq nor python3 available — skipping dependencies in ${deps_file}"
  fi
}

# --- Core processor ---

# Fetch a source, create its symlink, and recurse into its dependencies.
# Args: source_ref depth
process_source() {
  local source_ref="$1"
  local depth="${2:-0}"

  [ -n "$source_ref" ] || return 0

  # Parse the ref string — sets _SRC_* globals
  parse_source_ref "$source_ref" || return 1

  local source_key="${_SRC_OWNER}/${_SRC_REPO}/${_SRC_PATH}@${_SRC_REF}"

  # Cycle / duplicate detection
  if grep -qxF "$source_key" "$VISITED_FILE" 2>/dev/null; then
    hook_log "skipping (already processed): ${source_key}"
    return 0
  fi
  echo "$source_key" >> "$VISITED_FILE"

  hook_log_step "fetch-${_SRC_NAME}" "Fetching ${source_key}"

  local cache_dir
  cache_dir="$(get_cache_dir "$_SRC_OWNER" "$_SRC_REPO" "$_SRC_REF")"

  if ! fetch_into_cache "$_SRC_OWNER" "$_SRC_REPO" "$_SRC_REF" "$_SRC_PATH"; then
    return 1
  fi

  local rules_path="${cache_dir}/${_SRC_PATH}"
  if [ ! -d "$rules_path" ]; then
    hook_fail "path-missing" \
      "Path '${_SRC_PATH}' not found in ${_SRC_OWNER}/${_SRC_REPO}@${_SRC_REF}" \
      "Verify the path exists in the repository"
    return 1
  fi

  setup_symlink "$rules_path" "$PROJECT_RULES_DIR" "$_SRC_NAME"

  if [ "$ALSO_SYNC_TO_USER" = "true" ]; then
    setup_symlink "$rules_path" "$USER_RULES_DIR" "$_SRC_NAME"
  fi

  # Recursively resolve dependencies only when explicitly opted in
  if [ "$FOLLOW_DEPENDENCIES" != "true" ]; then
    if [ -f "${rules_path}/.shared-rules.yaml" ]; then
      hook_log "note: ${_SRC_NAME} has .shared-rules.yaml dependencies — set followDependencies: true to resolve them"
    fi
  elif [ "$depth" -lt 10 ]; then
    local dep
    while IFS= read -r dep; do
      [ -n "$dep" ] && { process_source "$dep" "$((depth + 1))" || hook_log "WARNING: failed to process dependency: ${dep}"; }
    done < <(read_dependencies "$rules_path")
  else
    hook_log "WARNING: max dependency depth (10) reached — stopping recursion at ${source_key}"
  fi
}

# --- Main ---

# Warn if yq is unavailable (required for reliable YAML parsing)
if ! command -v yq &>/dev/null; then
  hook_log "WARNING: yq not available — source parsing may be unreliable; install yq via mise"
fi

# Read configured sources using the shared 3-tier config library
readarray -t SOURCES < <(plugin_get_config_array "sources" || true)

if [ ${#SOURCES[@]} -eq 0 ]; then
  hook_log "no sources configured — add sources to plugins.settings.yaml:"
  hook_log "  poc-shared-rules:"
  hook_log "    sources:"
  hook_log "      - \"my-rules=owner/repo@main:/path/to/rules\""
  hook_respond
  exit 0
fi

# Temporary file for cycle detection (scoped to this run)
VISITED_FILE="$(mktemp)"
trap 'rm -f "$VISITED_FILE"' EXIT

hook_log_step "sync-rules" "Syncing ${#SOURCES[@]} source(s)"

for source_ref in "${SOURCES[@]}"; do
  process_source "$source_ref" 0 || hook_log "WARNING: failed to process source: ${source_ref}"
done

hook_log "rules synced"
hook_log_cleanup
hook_respond
