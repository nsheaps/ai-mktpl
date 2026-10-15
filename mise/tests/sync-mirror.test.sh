#!/usr/bin/env bash
# Tests for mise/tasks/sync-mirror using local bare repos as "self" and "peer".
# Run: bash mise/tests/sync-mirror.test.sh
set -uo pipefail

SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/tasks/sync-mirror"
ROOT="$(mktemp -d)"
trap 'rm -rf "$ROOT"' EXIT
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t

pass=0
fail=0
check() {
  local desc="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    pass=$((pass + 1))
    echo "ok   - $desc"
  else
    fail=$((fail + 1))
    echo "FAIL - $desc (expected '$expected', got '$actual')"
  fi
}

# Fresh pair of bare repos plus one clone each, both starting at the same commit.
setup() {
  rm -rf "$ROOT/a.git" "$ROOT/b.git" "$ROOT/a" "$ROOT/b"
  git init -q --bare -b main "$ROOT/a.git"
  git init -q --bare -b main "$ROOT/b.git"
  git clone -q "$ROOT/a.git" "$ROOT/a" 2>/dev/null
  git -C "$ROOT/a" checkout -q -b main 2>/dev/null || true
  echo base >"$ROOT/a/base.txt"
  git -C "$ROOT/a" add . && git -C "$ROOT/a" commit -qm base
  git -C "$ROOT/a" push -q origin main
  git -C "$ROOT/a" push -q "$ROOT/b.git" main
  git clone -q "$ROOT/b.git" "$ROOT/b"
}
commit() { # dir file content
  echo "$3" >"$1/$2"
  git -C "$1" add . && git -C "$1" commit -qm "edit $2"
  git -C "$1" push -q origin HEAD:main
}
tip() { git --git-dir="$ROOT/$1.git" rev-parse main; }
run() { env SYNC_SELF_URL="$ROOT/a.git" SYNC_PEER_URL="$ROOT/b.git" SYNC_MAX_ATTEMPTS=1 "$@" bash "$SCRIPT" 2>"$ROOT/log"; }

# 1. Already in sync: no-op
setup
run; check "in sync: exits 0" 0 $?
check "in sync: tips unchanged" "$(tip a)" "$(tip b)"

# 2. Self ahead: peer fast-forwards to self
setup; commit "$ROOT/a" a.txt one
run; check "self ahead: exits 0" 0 $?
check "self ahead: peer == self" "$(tip a)" "$(tip b)"

# 3. Peer ahead: self fast-forwards to peer (the "pull" direction)
setup; commit "$ROOT/b" b.txt one
run; check "peer ahead: exits 0" 0 $?
check "peer ahead: self == peer" "$(tip b)" "$(tip a)"

# 4. Diverged, non-conflicting: merge commit lands on both sides
setup; commit "$ROOT/a" a.txt one; commit "$ROOT/b" b.txt two
run; check "diverged clean: exits 0" 0 $?
check "diverged clean: tips equal" "$(tip a)" "$(tip b)"
git clone -q "$ROOT/a.git" "$ROOT/verify" 2>/dev/null
check "diverged clean: both files present" "2" "$(ls "$ROOT/verify" | grep -cE '^(a|b)\.txt$')"
check "diverged clean: tip is a merge commit" "2" "$(git --git-dir="$ROOT/a.git" rev-list --parents -n1 main | wc -w | awk '{print $1-1}')"
rm -rf "$ROOT/verify"

# 5. Diverged, conflicting: fails and pushes nothing
setup; commit "$ROOT/a" same.txt left; commit "$ROOT/b" same.txt right
before_a="$(tip a)"; before_b="$(tip b)"
run; check "diverged conflict: exits non-zero" 1 $?
check "diverged conflict: self untouched" "$before_a" "$(tip a)"
check "diverged conflict: peer untouched" "$before_b" "$(tip b)"
check "diverged conflict: names the file" 1 "$(grep -q 'same.txt' "$ROOT/log" && echo 1 || echo 0)"

# 6. Loop termination: after a sync, running from the other side is a no-op
setup; commit "$ROOT/a" a.txt one
run
before="$(tip b)"
env SYNC_SELF_URL="$ROOT/b.git" SYNC_PEER_URL="$ROOT/a.git" bash "$SCRIPT" 2>"$ROOT/log"
check "reverse run: exits 0" 0 $?
check "reverse run: no new commits" "$before" "$(tip b)"
check "reverse run: reports in sync" 1 "$(grep -c 'in sync' "$ROOT/log")"

# 7. Branch missing on peer is created
setup
git -C "$ROOT/a" checkout -q -b feature && echo f >"$ROOT/a/f.txt" && git -C "$ROOT/a" add . && git -C "$ROOT/a" commit -qm f
git -C "$ROOT/a" push -q origin feature
run SYNC_BRANCHES="main feature"; check "missing branch: exits 0" 0 $?
check "missing branch: created on peer" "$(git --git-dir="$ROOT/a.git" rev-parse feature)" "$(git --git-dir="$ROOT/b.git" rev-parse feature)"

# 8. Dry run pushes nothing
setup; commit "$ROOT/a" a.txt one
before_b="$(tip b)"
run SYNC_DRY_RUN=true; check "dry run: exits 0" 0 $?
check "dry run: peer unchanged" "$before_b" "$(tip b)"
check "dry run: reports intent" 1 "$(grep -c 'dry run' "$ROOT/log")"

# 9. Merge is deterministic: the reverse orientation yields the identical commit
setup; commit "$ROOT/a" a.txt one; commit "$ROOT/b" b.txt two
old_a="$(tip a)"; old_b="$(tip b)"
run
merged_1="$(tip a)"
git --git-dir="$ROOT/a.git" update-ref refs/heads/main "$old_a"
git --git-dir="$ROOT/b.git" update-ref refs/heads/main "$old_b"
env SYNC_SELF_URL="$ROOT/b.git" SYNC_PEER_URL="$ROOT/a.git" bash "$SCRIPT" 2>"$ROOT/log"
check "deterministic merge: reverse run exits 0" 0 $?
check "deterministic merge: same commit from either side" "$merged_1" "$(tip a)"

# 10. An unreadable remote fails the run instead of reading as "no branch"
setup
env SYNC_SELF_URL="$ROOT/a.git" SYNC_PEER_URL="$ROOT/does-not-exist.git" bash "$SCRIPT" 2>"$ROOT/log"
check "unreadable peer: exits non-zero" 1 "$([ $? -ne 0 ] && echo 1 || echo 0)"
check "unreadable peer: says so" 1 "$(grep -q 'cannot read peer' "$ROOT/log" && echo 1 || echo 0)"

# 11. A network remote without a deploy key is refused up front
env SYNC_SELF_URL="git@github.com:o/self.git" SYNC_PEER_URL="git@github.com:o/peer.git" bash "$SCRIPT" 2>"$ROOT/log"
check "missing key: exits 2" 2 $?
check "missing key: names the variable" 1 "$(grep -q 'SYNC_SELF_DEPLOY_KEY is not set' "$ROOT/log" && echo 1 || echo 0)"

# 12. Glob / invalid branch names are rejected, not expanded
setup
before="$(tip b)"
run SYNC_BRANCHES='ma*'; check "glob branch: exits non-zero" 1 "$([ $? -ne 0 ] && echo 1 || echo 0)"
check "glob branch: reports invalid name" 1 "$(grep -q 'invalid branch name' "$ROOT/log" && echo 1 || echo 0)"
check "glob branch: nothing pushed" "$before" "$(tip b)"

echo
echo "passed=$pass failed=$fail"
[ "$fail" -eq 0 ]
