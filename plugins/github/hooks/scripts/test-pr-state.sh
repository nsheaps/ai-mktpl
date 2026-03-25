#!/usr/bin/env bash
# test-pr-state.sh — Unit tests for PR state tracking libraries
#
# Tests pure logic functions (URL parsing, validation, state diffing)
# without requiring GitHub API access.
#
# Usage: bash test-pr-state.sh
set -uo pipefail
# Note: errexit (-e) is intentionally disabled because functions under test
# return non-zero to indicate "changes detected" which is expected behavior.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASS=0
FAIL=0

# --- Test helpers ---

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "FAIL: ${label}"
    echo "  expected: ${expected}"
    echo "  actual:   ${actual}"
  fi
}

assert_ok() {
  local label="$1"
  shift
  if "$@" 2>/dev/null; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "FAIL: ${label} (expected success, got failure)"
  fi
}

assert_fail() {
  local label="$1"
  shift
  if "$@" 2>/dev/null; then
    FAIL=$((FAIL + 1))
    echo "FAIL: ${label} (expected failure, got success)"
  else
    PASS=$((PASS + 1))
  fi
}

# --- Stub dependencies ---

# Stub CLAUDE_PLUGIN_ROOT and log.sh for sourcing
export CLAUDE_PLUGIN_ROOT="${SCRIPT_DIR}/../.."
LOG_PREFIX="test"

# Minimal log stubs (avoid sourcing actual log.sh which writes to stderr)
log_info() { :; }
log_warn() { :; }
log_error() { :; }

# Source the libraries under test
source "${SCRIPT_DIR}/lib/pr-discover.sh"

# pr-state.sh needs jq; skip if not available
if ! command -v jq &>/dev/null; then
  echo "SKIP: jq not available, skipping pr-state tests"
  exit 0
fi

source "${SCRIPT_DIR}/lib/pr-state.sh"

# ============================================================
# Test: _pr_extract_owner_repo
# ============================================================

echo "--- _pr_extract_owner_repo ---"

_pr_extract_owner_repo "https://github.com/nsheaps/ai-mktpl.git"
assert_eq "HTTPS .git URL owner" "nsheaps" "$_PR_OWNER"
assert_eq "HTTPS .git URL repo" "ai-mktpl" "$_PR_REPO"

_pr_extract_owner_repo "https://github.com/nsheaps/ai-mktpl"
assert_eq "HTTPS URL owner" "nsheaps" "$_PR_OWNER"
assert_eq "HTTPS URL repo" "ai-mktpl" "$_PR_REPO"

_pr_extract_owner_repo "git@github.com:nsheaps/ai-mktpl.git"
assert_eq "SSH .git URL owner" "nsheaps" "$_PR_OWNER"
assert_eq "SSH .git URL repo" "ai-mktpl" "$_PR_REPO"

_pr_extract_owner_repo "git@github.com:nsheaps/ai-mktpl"
assert_eq "SSH URL owner" "nsheaps" "$_PR_OWNER"
assert_eq "SSH URL repo" "ai-mktpl" "$_PR_REPO"

_pr_extract_owner_repo "http://127.0.0.1:8080/git/nsheaps/ai-mktpl"
assert_eq "Web proxy URL owner" "nsheaps" "$_PR_OWNER"
assert_eq "Web proxy URL repo" "ai-mktpl" "$_PR_REPO"

assert_fail "Invalid URL returns failure" _pr_extract_owner_repo "https://gitlab.com/foo/bar"

# ============================================================
# Test: _pr_validate_identifier
# ============================================================

echo "--- _pr_validate_identifier ---"

assert_ok "Valid owner" _pr_validate_identifier "nsheaps"
assert_ok "Valid repo with dots" _pr_validate_identifier "ai-mktpl.test"
assert_ok "Valid with underscore" _pr_validate_identifier "my_repo"
assert_fail "Path traversal" _pr_validate_identifier "../etc/passwd"
assert_fail "Slash in name" _pr_validate_identifier "owner/repo"
assert_fail "Empty string" _pr_validate_identifier ""
assert_fail "Spaces" _pr_validate_identifier "my repo"
assert_fail "Semicolon injection" _pr_validate_identifier "repo;rm -rf /"

# ============================================================
# Test: _pr_state_diff — no changes
# ============================================================

echo "--- _pr_state_diff ---"

CACHE_DIR="$(mktemp -d)"
pr_state_init "$CACHE_DIR"

state_a='{"pr":{"title":"Test PR","body":"hello","draft":false,"state":"open","merged":false,"mergeable":true,"mergeable_state":"clean","labels":["bug"],"head_sha":"abc123","updated_at":"2026-01-01"},"reviews":[],"comments":[],"review_comments":[],"checks":{"total_count":1,"checks":[{"name":"ci","status":"completed","conclusion":"success"}]},"fetched_at":"2026-01-01T00:00:00Z"}'

_pr_state_diff "$state_a" "$state_a" "owner" "repo" "1"
assert_eq "Identical states — no changes" "0" "${#PR_STATE_CHANGES[@]}"

# ============================================================
# Test: _pr_state_diff — title change
# ============================================================

state_b="$(echo "$state_a" | jq '.pr.title = "Updated PR"')"
_pr_state_diff "$state_a" "$state_b" "owner" "repo" "1"
assert_eq "Title change detected" "1" "${#PR_STATE_CHANGES[@]}"

# ============================================================
# Test: _pr_state_diff — body change
# ============================================================

state_c="$(echo "$state_a" | jq '.pr.body = "new body"')"
_pr_state_diff "$state_a" "$state_c" "owner" "repo" "1"
assert_eq "Body change detected" "1" "${#PR_STATE_CHANGES[@]}"

# ============================================================
# Test: _pr_state_diff — draft toggle
# ============================================================

state_d="$(echo "$state_a" | jq '.pr.draft = true')"
_pr_state_diff "$state_a" "$state_d" "owner" "repo" "1"
assert_eq "Draft change count" "1" "${#PR_STATE_CHANGES[@]}"
echo "${PR_STATE_CHANGES[0]}" | grep -q "converted to draft"
assert_eq "Draft change message" "0" "$?"

# ============================================================
# Test: _pr_state_diff — new comment
# ============================================================

state_e="$(echo "$state_a" | jq '.comments = [{"user":"alice","body":"looks good","created_at":"2026-01-02","id":1}]')"
_pr_state_diff "$state_a" "$state_e" "owner" "repo" "1"
assert_eq "New comment detected" "1" "${#PR_STATE_CHANGES[@]}"

# ============================================================
# Test: _pr_state_diff — CI status change
# ============================================================

state_f="$(echo "$state_a" | jq '.checks.checks[0].conclusion = "failure"')"
_pr_state_diff "$state_a" "$state_f" "owner" "repo" "1"
assert_eq "CI change detected" "1" "${#PR_STATE_CHANGES[@]}"
echo "${PR_STATE_CHANGES[0]}" | grep -q "CI on"
assert_eq "CI change message prefix" "0" "$?"

# ============================================================
# Test: _pr_state_diff — label change (human-readable)
# ============================================================

state_g="$(echo "$state_a" | jq '.pr.labels = ["bug", "enhancement"]')"
_pr_state_diff "$state_a" "$state_g" "owner" "repo" "1"
assert_eq "Label change detected" "1" "${#PR_STATE_CHANGES[@]}"
echo "${PR_STATE_CHANGES[0]}" | grep -q '\[bug\]'
assert_eq "Label output is human-readable (not raw JSON)" "0" "$?"

# ============================================================
# Test: _pr_state_diff — merged PR
# ============================================================

state_h="$(echo "$state_a" | jq '.pr.state = "closed" | .pr.merged = true')"
_pr_state_diff "$state_a" "$state_h" "owner" "repo" "1"
local_merged=0
for change in "${PR_STATE_CHANGES[@]}"; do
  echo "$change" | grep -q "MERGED" && local_merged=1
done
assert_eq "Merged PR detected" "1" "$local_merged"

# ============================================================
# Test: _pr_state_diff — new review
# ============================================================

state_i="$(echo "$state_a" | jq '.reviews = [{"user":"bob","state":"APPROVED","submitted_at":"2026-01-02","body":"lgtm"}]')"
_pr_state_diff "$state_a" "$state_i" "owner" "repo" "1"
assert_eq "New review detected" "1" "${#PR_STATE_CHANGES[@]}"
echo "${PR_STATE_CHANGES[0]}" | grep -q "bob APPROVED"
assert_eq "Review includes user and state" "0" "$?"

# ============================================================
# Test: _pr_state_diff — new review comment
# ============================================================

state_j="$(echo "$state_a" | jq '.review_comments = [{"user":"carol","body":"nit: fix typo","path":"src/main.sh","created_at":"2026-01-02","id":1}]')"
_pr_state_diff "$state_a" "$state_j" "owner" "repo" "1"
assert_eq "New review comment detected" "1" "${#PR_STATE_CHANGES[@]}"
echo "${PR_STATE_CHANGES[0]}" | grep -q "carol on src/main.sh"
assert_eq "Review comment includes user and path" "0" "$?"

# ============================================================
# Test: _pr_state_diff — multiple simultaneous changes
# ============================================================

state_k="$(echo "$state_a" | jq '.pr.title = "New title" | .comments = [{"user":"dave","body":"hi","created_at":"2026-01-02","id":1}] | .checks.checks[0].conclusion = "failure"')"
_pr_state_diff "$state_a" "$state_k" "owner" "repo" "1"
assert_eq "Multiple changes detected (>=3)" "1" "$([ ${#PR_STATE_CHANGES[@]} -ge 3 ] && echo 1 || echo 0)"

# --- Cleanup ---
rm -rf "$CACHE_DIR"

# --- Summary ---
echo ""
echo "=== Test Results ==="
echo "Passed: ${PASS}"
echo "Failed: ${FAIL}"
echo "Total:  $((PASS + FAIL))"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi

echo "All tests passed."
exit 0
