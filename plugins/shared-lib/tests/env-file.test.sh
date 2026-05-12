#!/usr/bin/env bash
# env-file.test.sh — tests for plugins/shared-lib/lib/env-file.sh
#
# Run from anywhere:
#   bash plugins/shared-lib/tests/env-file.test.sh

set -uo pipefail

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMPDIR_TEST="$(mktemp -d -t shared-lib-env-file.XXXXXX)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT

# shellcheck source=/dev/null
source "$PLUGIN_ROOT/lib/env-file.sh"

pass=0; fail=0
ok()  { echo "  ✓ $*"; pass=$((pass + 1)); }
bad() { echo "  ✗ $*"; fail=$((fail + 1)); }

# Assert that exactly $1 lines in $2 match ERE $3
assert_line_count() {
  local expected="$1" file="$2" pattern="$3" desc="$4"
  local count
  count="$(grep -E -c -- "$pattern" "$file" 2>/dev/null || true)"
  if [ "${count:-0}" = "$expected" ]; then
    ok "$desc (count=$count)"
  else
    bad "$desc (expected $expected, got ${count:-0})"
    echo "    file contents:" >&2
    sed 's/^/      /' "$file" >&2 || true
  fi
}

# Assert that a fixed line appears exactly $1 times in $2
assert_fixed_count() {
  local expected="$1" file="$2" needle="$3" desc="$4"
  local count
  count="$(grep -F -x -c -- "$needle" "$file" 2>/dev/null || true)"
  if [ "${count:-0}" = "$expected" ]; then
    ok "$desc (count=$count)"
  else
    bad "$desc (expected $expected, got ${count:-0})"
    echo "    file contents:" >&2
    sed 's/^/      /' "$file" >&2 || true
  fi
}

# --- Test 1: upsert when key doesn't exist appends -------------------------
echo "Test 1: upsert export to empty file"
f1="$TMPDIR_TEST/test1.env"
env_file_upsert_export "$f1" "FOO" "bar"
assert_line_count 1 "$f1" "^export FOO=" "FOO appended once"

# --- Test 2: upsert when key exists replaces (only one remains) ------------
echo "Test 2: upsert export idempotent on repeated calls"
f2="$TMPDIR_TEST/test2.env"
env_file_upsert_export "$f2" "FOO" "first"
env_file_upsert_export "$f2" "FOO" "second"
env_file_upsert_export "$f2" "FOO" "third"
assert_line_count 1 "$f2" "^export FOO=" "FOO appears exactly once after 3 upserts"
# Verify final value is "third"
if grep -E -q "^export FOO=third\$|^export FOO=\"third\"\$|^export FOO='third'\$" "$f2"; then
  ok "FOO final value is 'third'"
else
  bad "FOO final value is not 'third': $(grep '^export FOO=' "$f2")"
fi

# --- Test 3: upsert preserves other keys -----------------------------------
echo "Test 3: upsert preserves unrelated keys"
f3="$TMPDIR_TEST/test3.env"
env_file_upsert_export "$f3" "ALPHA" "1"
env_file_upsert_export "$f3" "BETA"  "2"
env_file_upsert_export "$f3" "ALPHA" "1-updated"
assert_line_count 1 "$f3" "^export ALPHA=" "ALPHA still one line"
assert_line_count 1 "$f3" "^export BETA="  "BETA still present"

# --- Test 4: special characters preserved via printf %q --------------------
echo "Test 4: special chars in value preserved"
f4="$TMPDIR_TEST/test4.env"
tricky='hello world $foo "quoted" '"'"'sq'"'"' \backslash'
env_file_upsert_export "$f4" "TRICKY" "$tricky"
# Source the file in a clean subshell and verify $TRICKY == original
roundtrip="$(bash -c "unset TRICKY; source '$f4'; printf '%s' \"\$TRICKY\"")"
if [ "$roundtrip" = "$tricky" ]; then
  ok "special chars round-trip via source"
else
  bad "round-trip mismatch: expected [$tricky] got [$roundtrip]"
fi

# --- Test 5: empty value is valid ------------------------------------------
echo "Test 5: empty value supported"
f5="$TMPDIR_TEST/test5.env"
env_file_upsert_export "$f5" "EMPTY" ""
assert_line_count 1 "$f5" "^export EMPTY=" "EMPTY var written"
roundtrip="$(bash -c "EMPTY=preset; source '$f5'; printf '%s' \"\$EMPTY\"")"
if [ -z "$roundtrip" ]; then
  ok "empty value round-trips as empty"
else
  bad "empty value round-trip got [$roundtrip]"
fi

# --- Test 6: source upsert is idempotent -----------------------------------
echo "Test 6: source upsert idempotent"
f6="$TMPDIR_TEST/test6.env"
src_path="/some/path/with.dots/.env.local"
env_file_upsert_source "$f6" "$src_path"
env_file_upsert_source "$f6" "$src_path"
env_file_upsert_source "$f6" "$src_path"
assert_fixed_count 1 "$f6" "source $src_path" "source line present exactly once"

# --- Test 7: source upsert preserves other source lines --------------------
echo "Test 7: source upsert preserves other source lines"
f7="$TMPDIR_TEST/test7.env"
env_file_upsert_source "$f7" "/path/a"
env_file_upsert_source "$f7" "/path/b"
env_file_upsert_source "$f7" "/path/a"
assert_fixed_count 1 "$f7" "source /path/a" "path/a present once"
assert_fixed_count 1 "$f7" "source /path/b" "path/b still present"

# --- Test 8: remove on non-existent file is no-op --------------------------
echo "Test 8: remove on missing file is silent no-op"
f8="$TMPDIR_TEST/test8-missing.env"
if env_file_remove_export "$f8" "FOO" 2>/dev/null; then
  ok "remove_export no-op on missing file"
else
  bad "remove_export errored on missing file"
fi
if env_file_remove_source "$f8" "/some/path" 2>/dev/null; then
  ok "remove_source no-op on missing file"
else
  bad "remove_source errored on missing file"
fi
if [ ! -e "$f8" ]; then
  ok "remove on missing file did not create it"
else
  bad "remove on missing file unexpectedly created it"
fi

# --- Test 9: remove existing line works ------------------------------------
echo "Test 9: remove deletes existing line"
f9="$TMPDIR_TEST/test9.env"
env_file_upsert_export "$f9" "DOOMED" "x"
env_file_upsert_export "$f9" "KEEP"   "y"
env_file_remove_export "$f9" "DOOMED"
assert_line_count 0 "$f9" "^export DOOMED=" "DOOMED removed"
assert_line_count 1 "$f9" "^export KEEP="   "KEEP still present"

env_file_upsert_source "$f9" "/path/x"
env_file_upsert_source "$f9" "/path/y"
env_file_remove_source "$f9" "/path/x"
assert_fixed_count 0 "$f9" "source /path/x" "source /path/x removed"
assert_fixed_count 1 "$f9" "source /path/y" "source /path/y kept"

# --- Test 10: file created when it doesn't exist ---------------------------
echo "Test 10: upsert creates missing file (and parent dir)"
f10="$TMPDIR_TEST/sub/dir/test10.env"
env_file_upsert_export "$f10" "NEW" "ok"
if [ -f "$f10" ]; then
  ok "file (and parent dirs) created on upsert"
else
  bad "file not created"
fi

# --- Test 11: prefix-match safety (FOO vs FOOBAR) --------------------------
echo "Test 11: similar key names don't collide"
f11="$TMPDIR_TEST/test11.env"
env_file_upsert_export "$f11" "FOO"    "1"
env_file_upsert_export "$f11" "FOOBAR" "2"
env_file_upsert_export "$f11" "FOO"    "1-updated"
assert_line_count 1 "$f11" "^export FOO="    "FOO line count 1 (matches FOO and FOOBAR via regex prefix — see note)"
assert_line_count 1 "$f11" "^export FOOBAR=" "FOOBAR still present"
# Note: `^export FOO=` regex matches `export FOO=` but NOT `export FOOBAR=`
# because of the literal `=` boundary. This test confirms that.

# --- Test 12: upsert preserves existing file's permissions -----------------
# `mktemp` creates the tmp file at 0600; `mv` keeps the source inode's mode,
# so without explicit perm replay, the target would silently be downgraded
# to 0600. Verify the helper preserves the target's pre-existing mode.
echo "Test 12: upsert preserves existing file perms (0644 stays 0644)"
f12="$TMPDIR_TEST/test12.env"
: > "$f12"
chmod 644 "$f12"
env_file_upsert_export "$f12" "PERMSKEY" "permsval"
# Stat the mode in octal — try GNU first, fall back to BSD.
mode12="$(stat -c '%a' -- "$f12" 2>/dev/null || stat -f '%Lp' -- "$f12" 2>/dev/null || echo "?")"
if [ "$mode12" = "644" ]; then
  ok "perms preserved as 0644 after upsert"
else
  bad "perms NOT preserved: expected 644, got $mode12"
fi

echo "Test 12b: upsert preserves perms across multiple calls (0664)"
f12b="$TMPDIR_TEST/test12b.env"
: > "$f12b"
chmod 664 "$f12b"
env_file_upsert_export "$f12b" "K1" "v1"
env_file_upsert_export "$f12b" "K1" "v2"
env_file_upsert_source "$f12b" "/some/path"
mode12b="$(stat -c '%a' -- "$f12b" 2>/dev/null || stat -f '%Lp' -- "$f12b" 2>/dev/null || echo "?")"
if [ "$mode12b" = "664" ]; then
  ok "perms preserved as 0664 across upserts"
else
  bad "perms NOT preserved across upserts: expected 664, got $mode12b"
fi

# --- Test 13: first-write (file doesn't exist) leaves tmp at 0600 ---------
# When the target doesn't exist yet, we have no prior perms to replay, so
# mktemp's 0600 default is what the new file ends up with. This is the
# safe default for env files that may hold secrets.
echo "Test 13: first-write to nonexistent file ends at 0600"
f13="$TMPDIR_TEST/test13-new.env"
[ ! -e "$f13" ] || rm -f "$f13"
env_file_upsert_export "$f13" "NEW_KEY" "newval"
mode13="$(stat -c '%a' -- "$f13" 2>/dev/null || stat -f '%Lp' -- "$f13" 2>/dev/null || echo "?")"
if [ "$mode13" = "600" ]; then
  ok "first-write file ends at 0600 (safe default for secrets)"
else
  bad "first-write perms unexpected: expected 600, got $mode13"
fi

# --- Summary ----------------------------------------------------------------
echo
echo "Results: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
