#!/bin/sh
# run-probe-tests.sh — tests the probe scripts' tool-detection and output-parsing
# paths against real captured tool output.
#
# Usage:
#   run-probe-tests.sh [--verbose]
#
# Every probe follows the same three-way contract:
#
#   tool missing          -> "# tool=<bin> status=missing", ZERO findings
#   tool present, clean   -> "# tool=<bin> status=ran",     ZERO findings
#   tool present, dirty   -> "# tool=<bin> status=ran",     one finding per tool
#                            diagnostic, each carrying the right FILE and LINE
#
# The middle case is the one worth testing hardest: if a clean scan were reported
# as "unavailable", a passing scanner would read as an unrun one, and the aspect
# would understate its own coverage. If a dirty scan were parsed to zero findings,
# the aspect would report clean while the tool found things -- silent, and worse
# than the tool being absent, because "unavailable" at least announces itself.
#
# Tools are simulated with PATH shims that replay a fixture from fixtures/,
# captured from the real tool (see fixtures/SOURCES.md). The probe's own grep and
# sed filters run for real, so a filter that does not match its tool's actual
# output fails here.
#
# Output: one line per assertion, "ok N - <name>" or "not ok N - <name>".
# Exit: 0 if every assertion passed, 1 otherwise.

set -u

VERBOSE=0
[ "${1:-}" = "--verbose" ] && VERBOSE=1

TESTS_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
FIX="$TESTS_DIR/fixtures"
SKILLS=$(CDPATH= cd -- "$TESTS_DIR/../skills" && pwd)

N=0
FAILED=0

ok() {
  N=$((N + 1))
  echo "ok $N - $1"
}

not_ok() {
  N=$((N + 1))
  FAILED=$((FAILED + 1))
  echo "not ok $N - $1"
  [ -n "${2:-}" ] && echo "#   $2"
}

WORK=$(mktemp -d) || exit 1
trap 'rm -rf "$WORK"' EXIT INT TERM

# Build a PATH directory holding shims. Each shim ignores its arguments and
# replays the fixture, which is enough: the probe's filters read stdout only.
shim() { # shim <name> <fixture-or-empty>
  mkdir -p "$WORK/bin"
  if [ -n "${2:-}" ]; then
    printf '#!/bin/sh\ncat %s\n' "$FIX/$2" >"$WORK/bin/$1"
  else
    printf '#!/bin/sh\nexit 0\n' >"$WORK/bin/$1"
  fi
  chmod +x "$WORK/bin/$1"
}

# A minimal repo for the probe to run in. git is real: several probe commands are
# guarded on git state, and shimming git would test the shim, not the probe.
new_repo() {
  rm -rf "$WORK/repo" "$WORK/bin"
  mkdir -p "$WORK/repo/.github/workflows" "$WORK/repo/docs" "$WORK/repo/src"
  : >"$WORK/repo/.github/workflows/ci.yml"
  : >"$WORK/repo/docs/index.md"
  : >"$WORK/repo/requirements.txt"
  (
    cd "$WORK/repo" || exit 1
    git init -q .
    git add -A
    git -c user.email=t@example.com -c user.name=t commit -qm init
  )
}

run_probe() { # run_probe <family> ; stdout -> $WORK/out
  fam=$1
  PATH="$WORK/bin:$PATH" "$SKILLS/$fam/scripts/probe-$fam.sh" "$WORK/repo" >"$WORK/out" 2>"$WORK/err"
  [ "$VERBOSE" -eq 1 ] && cat "$WORK/out"
  return 0
}

# grep -c prints 0 and exits 1 when nothing matches, so `|| echo 0` would emit
# two lines. Capture the count and default it instead.
findings() {
  c=$(grep -cE '^(blocker|major|minor|nit)\|' "$WORK/out" 2>/dev/null)
  [ -n "$c" ] || c=0
  printf '%s' "$c"
}
finding_for() { grep -E "^[a-z]+\|[^|]*\|[0-9]+\|[^|]*$1" "$WORK/out" 2>/dev/null; }

# --- Case 1: tool missing -> status=missing, zero findings -------------------
new_repo
run_probe docs
if grep -q '^# tool=lychee status=missing' "$WORK/out"; then
  ok "docs: absent lychee reports status=missing"
else
  not_ok "docs: absent lychee reports status=missing" "$(grep lychee "$WORK/out" || echo 'no lychee line')"
fi
if [ "$(findings)" -eq 0 ]; then
  ok "docs: absent tools produce zero findings"
else
  not_ok "docs: absent tools produce zero findings" "got $(findings)"
fi

# --- Case 2: tool present but clean -> status=ran, zero findings -------------
new_repo
shim lychee ""
shim markdownlint-cli2 ""
shim cspell ""
run_probe docs
if grep -q '^# tool=lychee status=ran' "$WORK/out"; then
  ok "docs: silent lychee reports status=ran, not missing"
else
  not_ok "docs: silent lychee reports status=ran, not missing" "$(grep lychee "$WORK/out" || echo none)"
fi
if [ "$(findings)" -eq 0 ]; then
  ok "docs: clean tools produce zero findings"
else
  not_ok "docs: clean tools produce zero findings" "got $(findings)"
fi

# --- Case 3: tool present with findings, per tool ----------------------------
# docs: lychee (no line numbers), markdownlint (line with and without column),
# cspell (line:col).
new_repo
shim lychee lychee.txt
shim markdownlint-cli2 markdownlint-cli2.txt
shim cspell cspell.txt
run_probe docs
if [ "$(finding_for 'docs-link-graph-integrity' | wc -l)" -ge 1 ]; then
  ok "docs: lychee [ERROR] lines survive the filter"
else
  not_ok "docs: lychee [ERROR] lines survive the filter" "zero link findings parsed"
fi
if finding_for 'docs-presentation' | grep -q '|docs/broken.md|1|'; then
  ok "docs: markdownlint 'file:line error' (no column) parses to line 1"
else
  not_ok "docs: markdownlint 'file:line error' (no column) parses to line 1" "$(finding_for 'docs-presentation' | head -2)"
fi
if finding_for 'docs-presentation' | grep -q '|docs/broken.md|3|'; then
  ok "docs: markdownlint 'file:line:col error' parses to line 3"
else
  not_ok "docs: markdownlint 'file:line:col error' parses to line 3" "$(finding_for 'docs-presentation' | head -2)"
fi
if finding_for 'docs-terminology-consistency' | grep -q '|docs/broken.md|7|'; then
  ok "docs: cspell 'file:line:col -' parses to line 7"
else
  not_ok "docs: cspell 'file:line:col -' parses to line 7" "$(finding_for 'docs-terminology-consistency' | head -2)"
fi

# security: semgrep --vim, zizmor plain (location on a separate line),
# actionlint, osv-scanner table rows.
new_repo
shim semgrep semgrep.vim.txt
shim zizmor zizmor.plain.txt
shim actionlint actionlint.txt
shim osv-scanner osv-scanner.txt
run_probe security
if finding_for 'sec-injection-interpreter' | grep -q '|src/vuln.py|5|'; then
  ok "security: semgrep --vim parses to src/vuln.py:5"
else
  not_ok "security: semgrep --vim parses to src/vuln.py:5" "$(finding_for 'sec-injection-interpreter' | head -2)"
fi
if finding_for 'sec-ci-trigger-privilege' | grep -q '|.github/workflows/bad.yml|7|'; then
  ok "security: zizmor's separate --> location line is paired with its rule"
else
  not_ok "security: zizmor's separate --> location line is paired with its rule" "$(finding_for 'sec-ci' | head -2)"
fi
if finding_for 'sec-ci-trigger-privilege' | grep -q '|.github/workflows/bad.yml|8|'; then
  ok "security: actionlint 'file:line:col:' parses to line 8"
else
  not_ok "security: actionlint 'file:line:col:' parses to line 8" "$(finding_for 'sec-ci' | head -3)"
fi
if [ "$(finding_for 'sec-dep-vuln-maintenance' | wc -l)" -ge 1 ]; then
  ok "security: osv-scanner advisory rows survive the filter"
else
  not_ok "security: osv-scanner advisory rows survive the filter" "zero advisories parsed"
fi

# design: vulture (line then space), jscpd (rewritten from its clone rows).
new_repo
shim vulture vulture.txt
shim jscpd jscpd.consolefull.txt
run_probe design
if finding_for 'design-api-surface-minimality' | grep -q '|src/dead.py|4|'; then
  ok "design: vulture 'file:line: msg' parses to src/dead.py:4"
else
  not_ok "design: vulture 'file:line: msg' parses to src/dead.py:4" "$(finding_for 'design-api' | head -2)"
fi
if finding_for 'design-duplication' | grep -q '|dup1.js|1|'; then
  ok "design: jscpd clone rows are rewritten to file:line"
else
  not_ok "design: jscpd clone rows are rewritten to file:line" "$(finding_for 'design-duplication' | head -2)"
fi

# --- Case 4: battery present -> the probe says so and defers ------------------
new_repo
mkdir -p "$WORK/repo/.review"
cp "$FIX/battery.sarif" "$WORK/repo/.review/battery.sarif"
run_probe security
if grep -q '^# battery=present' "$WORK/out"; then
  ok "security: an existing .review/battery.sarif is announced as present"
else
  not_ok "security: an existing .review/battery.sarif is announced as present" "$(grep battery "$WORK/out" || echo none)"
fi
new_repo
run_probe security
if grep -q '^# battery=absent' "$WORK/out"; then
  ok "security: a missing battery is announced as absent"
else
  not_ok "security: a missing battery is announced as absent" "$(grep battery "$WORK/out" || echo none)"
fi

# --- Case 5: a pipe inside a diagnostic does not shift the fields ------------
# Regression: the output contract is pipe-delimited, and tool messages contain
# pipes (regex alternations, table output). An unescaped one would silently move
# every downstream field, so MESSAGE and FILE escape theirs as '\|'.
new_repo
shim markdownlint-cli2 synthetic-pipe-in-message.txt
run_probe docs
line=$(grep -E '^[a-z]+\|[^|]*\|[0-9]+\|[^|]*docs-presentation' "$WORK/out" | head -1)
fieldcount=$(printf '%s' "$line" | sed 's/\\|//g' | awk -F'|' '{print NF}')
if [ "$fieldcount" = "5" ]; then
  ok "probe: a message containing pipes still yields exactly 5 fields"
else
  not_ok "probe: a message containing pipes still yields exactly 5 fields" "NF=$fieldcount in: $line"
fi
if printf '%s' "$line" | grep -q '\\|'; then
  ok "probe: literal pipes in the message are escaped as \\|"
else
  not_ok "probe: literal pipes in the message are escaped as \\|" "$line"
fi

# --- Case 6: the org-fit task runner is only used read-only ------------------
# Regression: 'mise run lint' can be a FIXING task in this org (CI auto-commits
# formatter output). Three behaviours are pinned: no check-only task means
# unavailable, not clean; a check-only task is run and parsed; and a task that
# writes anyway is caught and its findings discarded.
mise_shim() { # mise_shim <tasks-listing> <run-body>
  mkdir -p "$WORK/bin"
  {
    echo '#!/bin/sh'
    echo 'case "$1 $2" in'
    echo '"tasks ls")'
    printf '\tprintf %s\n' "'%s\\n' $1"
    echo '	exit 0 ;;'
    echo 'esac'
    echo 'if [ "$1" = "run" ]; then'
    echo "	$2"
    echo '	exit 0'
    echo 'fi'
    echo 'exit 0'
  } >"$WORK/bin/mise"
  chmod +x "$WORK/bin/mise"
}

new_repo
mise_shim "lint format" 'echo "src/a.js:1:1: never reached"'
run_probe org-fit
if grep -q '^# tool=mise status=missing' "$WORK/out" && [ "$(findings)" -eq 0 ]; then
  ok "org-fit: a repo with only a fixing 'lint' task reports mise unavailable"
else
  not_ok "org-fit: a repo with only a fixing 'lint' task reports mise unavailable" \
    "$(grep mise "$WORK/out" || echo none)"
fi

new_repo
mise_shim "lint lint:check" 'echo "src/a.js:3:5: prefer const"'
run_probe org-fit
if grep -q '^# tool=mise status=ran' "$WORK/out" &&
  finding_for 'org-fit-repo-stated-rules' | grep -q '|src/a.js|3|'; then
  ok "org-fit: a check-only task runs and its diagnostics parse to file:line"
else
  not_ok "org-fit: a check-only task runs and its diagnostics parse to file:line" \
    "$(grep -E 'mise|org-fit-repo-stated' "$WORK/out" | head -3)"
fi

new_repo
mise_shim "lint lint:check" 'echo mutated >>"$PWD/docs/index.md"; echo "src/a.js:3:5: prefer const"'
run_probe org-fit
if finding_for 'org-fit-repo-stated-rules' | grep -q 'mutated the working tree' &&
  ! finding_for 'org-fit-repo-stated-rules' | grep -q 'prefer const'; then
  ok "org-fit: a task that writes to the tree is caught and its findings discarded"
else
  not_ok "org-fit: a task that writes to the tree is caught and its findings discarded" \
    "$(finding_for 'org-fit-repo-stated-rules' | head -3)"
fi

# --- Case 7: check-skill.sh sees every link on a line ------------------------
# Regression: a greedy sed anchored on the last '](' dropped earlier links, so a
# broken first link on a two-link line passed silently.
mkdir -p "$WORK/skill/two-links"
cat >"$WORK/skill/two-links/SKILL.md" <<'MD'
---
name: two-links
description: A fixture skill used to check that both links on one line are read. Trigger phrases - "two links fixture".
---

# Two links

See [first](references/missing-first.md) and [second](references/present-second.md).
MD
mkdir -p "$WORK/skill/two-links/references"
: >"$WORK/skill/two-links/references/present-second.md"
"$SKILLS/agentic-configuration/scripts/check-skill.sh" "$WORK/skill/two-links" >"$WORK/cs" 2>&1 || true
if grep -q 'missing-first.md' "$WORK/cs"; then
  ok "check-skill: the FIRST link on a two-link line is still checked"
else
  not_ok "check-skill: the FIRST link on a two-link line is still checked" \
    "$(grep -c . "$WORK/cs") lines, no mention of missing-first.md"
fi

# --- Case 7b: SK024 fires on background:false without compatibility ----------
# `background: false` is gated on Claude Code v2.1.218+; an older client ignores
# it and returns nothing, which reads as a clean result. Three fixtures, because
# a check that only ever fires is as useless as one that never does: the
# violator must be caught, the compliant skill must not, and `background: true`
# must not be reached at all.
for case in violator compliant bg-true; do
  mkdir -p "$WORK/sk024/$case"
done
cat >"$WORK/sk024/violator/SKILL.md" <<'MD'
---
name: violator
description: A fixture skill used to prove SK024 fires. Use when testing the checker.
context: fork
background: false
---

# Violator

## 1. Return contract

Returns rows.
MD
sed -e 's/^name: violator/name: compliant/' \
  -e 's/^background: false/background: false\ncompatibility: "Requires Claude Code v2.1.218 or later."/' \
  "$WORK/sk024/violator/SKILL.md" >"$WORK/sk024/compliant/SKILL.md"
sed -e 's/^name: violator/name: bg-true/' -e 's/^background: false/background: true/' \
  "$WORK/sk024/violator/SKILL.md" >"$WORK/sk024/bg-true/SKILL.md"

"$SKILLS/agentic-configuration/scripts/check-skill.sh" --quiet "$WORK/sk024/violator" >"$WORK/sk024.out" 2>&1 || true
if grep -q '|SK024|' "$WORK/sk024.out"; then
  ok "check-skill: SK024 fires on background:false with no compatibility"
else
  not_ok "check-skill: SK024 fires on background:false with no compatibility" \
    "got: $(cat "$WORK/sk024.out")"
fi

for case in compliant bg-true; do
  "$SKILLS/agentic-configuration/scripts/check-skill.sh" --quiet "$WORK/sk024/$case" >"$WORK/sk024.$case" 2>&1 || true
  if grep -q '|SK024|' "$WORK/sk024.$case"; then
    not_ok "check-skill: SK024 stays silent on the $case fixture" "got: $(cat "$WORK/sk024.$case")"
  else
    ok "check-skill: SK024 stays silent on the $case fixture"
  fi
done

# --- Case 8: aspect discovery admits only real aspects -----------------------
# Regression: 'ls review-*/' invoked any matching directory. The documented loop
# now requires a SKILL.md that forks and returns the shared contract, and skips
# the entry skill itself.
awk '/^for d in /{p=1} p{print} /^done$/{if(p)exit}' \
  "$SKILLS/start/SKILL.md" >"$WORK/discover.sh"
mkdir -p "$WORK/aspects/start" "$WORK/aspects/decoy" "$WORK/aspects/correctness"
: >"$WORK/aspects/decoy/SKILL.md"
cp "$SKILLS/correctness/SKILL.md" "$WORK/aspects/correctness/SKILL.md"
CLAUDE_SKILL_DIR="$WORK/aspects/start" sh "$WORK/discover.sh" >"$WORK/found" 2>/dev/null || true
if grep -qx 'correctness' "$WORK/found" &&
  ! grep -qx 'decoy' "$WORK/found" &&
  ! grep -qx 'start' "$WORK/found"; then
  ok "start: discovery admits a real aspect and rejects a decoy directory"
else
  not_ok "start: discovery admits a real aspect and rejects a decoy directory" \
    "found: $(tr '\n' ' ' <"$WORK/found")"
fi

# --- Case 9: every probe is syntax-clean and honours --list ------------------
for fam in correctness security design docs process org-fit best-practices; do
  if sh -n "$SKILLS/$fam/scripts/probe-$fam.sh" 2>/dev/null &&
    "$SKILLS/$fam/scripts/probe-$fam.sh" --list >/dev/null 2>&1; then
    ok "$fam: probe parses and --list runs without touching the repo"
  else
    not_ok "$fam: probe parses and --list runs without touching the repo"
  fi
done

echo "1..$N"
if [ "$FAILED" -gt 0 ]; then
  echo "# FAILED $FAILED of $N"
  exit 1
fi
echo "# passed $N of $N"
exit 0
