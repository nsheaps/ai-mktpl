#!/usr/bin/env bash
# sync-shared-lib.sh — Sync shared/lib/*.sh into vendored copies in each plugin's lib/
#
# This script copies shared/lib/*.sh into any plugin lib/ file that bears the
# vendoring header comment ("VENDORED FROM shared/lib/").
# It preserves the 3-line header block and replaces the rest of the file content.
#
# Idempotent: running twice with no shared/lib changes produces zero diff.
#
# Usage: scripts/sync-shared-lib.sh [--check]
#   --check: Exit non-zero if any vendored files are out of sync (CI mode).
#
# Context:
#   Workaround for upstream regression anthropics/claude-code#53948 in Claude Code
#   v2.1.117+ where plugin install fails to preserve symlinks under plugins/<name>/lib/,
#   leaving the directories empty in the cache.
#
# See: https://github.com/nsheaps/ai-mktpl/issues/474
#      https://github.com/anthropics/claude-code/issues/53948

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SHARED_LIB="${REPO_ROOT}/shared/lib"
PLUGINS_DIR="${REPO_ROOT}/plugins"
CHECK_MODE=""
case "${1:-}" in
  --check) CHECK_MODE="--check" ;;
  "") ;;
  *) echo "ERROR: unknown argument: $1" >&2; exit 2 ;;
esac

updated=0
already_up_to_date=0
errors=0

if [ ! -d "$SHARED_LIB" ]; then
  echo "ERROR: shared/lib directory not found at ${SHARED_LIB}" >&2
  exit 1
fi

# For each plugin lib/ file that has the vendoring header, sync it
while IFS= read -r vendored_file; do
  # Extract the source filename from line 1 of the header comment
  # Header line format: # ⚠️  VENDORED FROM shared/lib/<name>.sh
  header=$(head -1 "$vendored_file")
  if ! [[ "$header" =~ VENDORED\ FROM\ shared/lib/([A-Za-z0-9._-]+\.sh)$ ]]; then
    echo "WARN: malformed vendoring header in: ${vendored_file}" >&2
    errors=$((errors + 1))
    continue
  fi
  source_name="${BASH_REMATCH[1]}"

  source_file="${SHARED_LIB}/${source_name}"
  if [ ! -f "$source_file" ]; then
    echo "ERROR: source file not found: ${source_file}" >&2
    errors=$((errors + 1))
    continue
  fi

  # Extract the 3-line header block (lines 1-3 of the vendored file)
  header_line1=$(sed -n '1p' "$vendored_file")
  header_line2=$(sed -n '2p' "$vendored_file")
  header_line3=$(sed -n '3p' "$vendored_file")

  # Build the expected file content: 3 header lines + blank line + source content
  source_content=$(cat "$source_file")

  # Construct what the file should look like
  expected_content="${header_line1}
${header_line2}
${header_line3}
${source_content}"

  # Compare with existing
  existing_content=$(cat "$vendored_file")

  if [ "$expected_content" = "$existing_content" ]; then
    already_up_to_date=$((already_up_to_date + 1))
    continue
  fi

  if [ "$CHECK_MODE" = "--check" ]; then
    echo "DRIFT: ${vendored_file} is out of sync with shared/lib/${source_name}"
    errors=$((errors + 1))
    continue
  fi

  # Write the updated content
  printf '%s\n' "$expected_content" > "$vendored_file"
  echo "UPDATED: ${vendored_file} <- shared/lib/${source_name}"
  updated=$((updated + 1))

done < <(grep -rl 'VENDORED FROM shared/lib/' "${PLUGINS_DIR}" --include='*.sh' 2>/dev/null || true)

echo ""
echo "=== sync-shared-lib summary ==="
if [ "$CHECK_MODE" = "--check" ]; then
  echo "  Checked:          $((already_up_to_date + errors)) files"
  echo "  Up-to-date:       ${already_up_to_date}"
  echo "  Out-of-sync:      ${errors}"
else
  echo "  Updated:          ${updated}"
  echo "  Already current:  ${already_up_to_date}"
  if [ "$errors" -gt 0 ]; then
    echo "  Errors:           ${errors}"
  fi
fi

if [ "$errors" -gt 0 ]; then
  exit 1
fi
