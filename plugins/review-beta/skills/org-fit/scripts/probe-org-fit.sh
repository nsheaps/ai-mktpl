#!/bin/sh
# probe-org-fit.sh — programmatic pre-filter for the 'org-fit' review family.
#
# Runs the repo's own lint/format task plus the conformance, drift, portability and i18n checks that decide the org-fit family -- the family whose whole premise is that the repo already declared the rule.
#
# Usage:
#   probe-org-fit.sh [--base REF] [--list] [PATH]
#
#   --base REF  git ref the diff is measured against (default: origin/main,
#               then origin/master, then main, then master).
#   --list      print the tool table and exit without running anything.
#   PATH        repository root to probe (default: current directory).
#
# Output on stdout, one finding per line:
#   SEVERITY|FILE|LINE|DIMENSION|MESSAGE
# SEVERITY is blocker, major, minor or nit -- the dimension's ceiling, not the
# rated severity of the finding; the reviewer rates each finding against the
# taxonomy severity rubric and may land lower. LINE is 0 when a tool reports no
# line. Lines beginning '#' are metadata:
#   # battery=present|absent
#   # tool=<bin> status=ran|missing dimensions=<id,...>
#   # deferred=<id> reason=<text>
#   # summary tools_ran=<n> tools_missing=<n> findings=<n>
#
# A tool that is missing yields status=missing and ZERO findings for its
# dimensions. That is deliberate: no tool, no finding. A reviewer that fills the
# gap by eyeballing the diff will find what it was told to look for whether or
# not it is there. Report the dimension as unavailable instead.
#
# Findings are parsed from each tool's own output. A line shaped 'file:line:...'
# yields that file and line; anything else yields FILE '-' and LINE 0.
#
# The five fields are separated by unescaped '|'. A literal pipe inside FILE or
# MESSAGE is emitted escaped as '\|', so the field count is always five; a
# consumer unescapes '\|' back to '|' after splitting.
#
# Exit: 0 always -- a probe reports, it does not gate. Usage error exits 2.
#
# See ../references/dimensions.md for this family's dimension table and
# ../SKILL.md section 1 for how this output is consumed.

set -u

BASE=""
LIST=0
ROOT="."

usage() {
  echo "usage: probe-org-fit.sh [--base REF] [--list] [PATH]" >&2
  exit 2
}

while [ $# -gt 0 ]; do
  case "$1" in
  --base)
    [ $# -ge 2 ] || usage
    BASE=$2
    shift
    ;;
  --list) LIST=1 ;;
  -h | --help)
    sed -n '2,40p' "$0" | sed 's/^#\{1,\} \{0,1\}//'
    exit 0
    ;;
  -*) usage ;;
  *) ROOT=$1 ;;
  esac
  shift
done

[ -d "$ROOT" ] || {
  echo "probe-org-fit.sh: no such directory: $ROOT" >&2
  exit 2
}
cd "$ROOT" || exit 2

if [ -z "$BASE" ]; then
  for c in origin/main origin/master main master; do
    if git rev-parse --verify "$c" >/dev/null 2>&1; then
      BASE=$c
      break
    fi
  done
fi
export BASE

# dimension-id<TAB>binary<TAB>severity-ceiling<TAB>command
# Each command runs only when its binary resolves, must not mutate the tree, and
# must be cheap enough for a review turn. Suites that are not (fuzzers, mutation
# testing, load tests, deployed-endpoint probes) are declared deferred below and
# have to arrive from the CI battery instead.
#
# Read-only enforcement for the repo's own task runner: this org's convention is
# that the fixing task is 'format' and CI auto-commits its output, so a bare
# 'mise run lint' is NOT assumed safe. The mise row runs only a task whose name
# is explicitly check-only, and still brackets the run with a working-tree
# fingerprint; if the task wrote anything, its output is discarded and the row
# reports the mutation instead of leaking half-trustworthy findings.
# 'prettier --check' and 'go mod tidy -diff' are the read-only spellings of
# their respective tools (--check / -diff report and exit non-zero, never write).
TOOLS=$(
  cat <<'TOOLTABLE'
org-fit-repo-stated-rules,org-fit-interface-convention-conformance	mise	major	t=$(mise tasks ls 2>/dev/null | awk '{print $1}' | grep -xE 'lint:check|lint-check|check|format:check|format-check' | head -1); [ -n "$t" ] || exit 0; b=$(git status --porcelain 2>/dev/null; git diff 2>/dev/null | cksum); o=$(mise run "$t" 2>&1); a=$(git status --porcelain 2>/dev/null; git diff 2>/dev/null | cksum); if [ "$b" != "$a" ]; then echo "-:0: mise run $t mutated the working tree; its findings were discarded - treat this dimension as unavailable"; exit 0; fi; printf '%s\n' "$o" | grep -E ':[0-9]+:[0-9]+' || true
org-fit-repo-stated-rules	editorconfig-checker	minor	editorconfig-checker 2>&1 | grep -E ':[0-9]+' || true
org-fit-repo-stated-rules	prettier	minor	prettier --check . 2>&1 | grep -E '^\[warn\] ' || true
org-fit-interface-convention-conformance	eslint	major	eslint . -f unix 2>/dev/null | grep -E ':[0-9]+:[0-9]+' || true
org-fit-interface-convention-conformance	buf	major	[ -f buf.yaml ] && buf lint 2>&1 | grep -E ':[0-9]+:[0-9]+' || true
org-fit-dependency-version-divergence	syncpack	major	syncpack list-mismatches 2>/dev/null | grep -E '^ *[✘x] ' || true
org-fit-generated-artifact-drift	go	major	[ -f go.mod ] && go mod tidy -diff 2>&1 | grep -E '^(diff|-|\+)' | head -20 || true
org-fit-platform-assumption-leakage	shellcheck	major	git ls-files '*.sh' 2>/dev/null | xargs -r shellcheck -s sh -f gcc 2>/dev/null | grep -E ':[0-9]+:[0-9]+' || true
org-fit-platform-assumption-leakage	git	major	git ls-files 2>/dev/null | tr 'A-Z' 'a-z' | sort | uniq -d | sed 's/$/:0: path collides case-insensitively with another tracked path/' || true
org-fit-i18n	eslint	major	eslint . -f unix --rule '{"i18next/no-literal-string":"warn"}' 2>/dev/null | grep -E 'no-literal-string' || true
TOOLTABLE
)

if [ "$LIST" -eq 1 ]; then
  printf '%s\n' "$TOOLS"
  exit 0
fi

TMP=$(mktemp -d) || exit 2
trap 'rm -rf "$TMP"' EXIT INT TERM
# Exported so a tool row that needs scratch space uses this private,
# trap-cleaned directory rather than a predictable path in shared /tmp.
export TMP
: >"$TMP/findings"
: >"$TMP/meta"

# A CI run that already produced the merged battery is authoritative: rerunning a
# scanner here duplicates results the aggregator has partitioned by dimension.
if [ -f .review/battery.sarif ]; then
  echo "# battery=present path=.review/battery.sarif" >>"$TMP/meta"
else
  echo "# battery=absent" >>"$TMP/meta"
fi

ran=0
missing=0

printf '%s\n' "$TOOLS" | grep -v '^[[:space:]]*$' | grep -v '^#' >"$TMP/tools"

# The repo's task runner counts as AVAILABLE only when it exposes a check-only
# task. A bare 'lint' task may be a fixing task in this org (CI auto-commits
# formatter output), so running it would mutate the tree; with no read-only
# invocation the honest report is unavailable, not a clean scan.
if command -v mise >/dev/null 2>&1 &&
  ! mise tasks ls 2>/dev/null | awk '{print $1}' |
    grep -qxE 'lint:check|lint-check|check|format:check|format-check'; then
  grep -v "^org-fit-repo-stated-rules,org-fit-interface-convention-conformance$(printf '\t')mise$(printf '\t')" \
    "$TMP/tools" >"$TMP/tools.f" || true
  mv "$TMP/tools.f" "$TMP/tools"
  printf '# tool=%s status=missing dimensions=%s reason=%s\n' \
    "mise" "org-fit-repo-stated-rules,org-fit-interface-convention-conformance" \
    "no check-only task; a fixing lint task is not a read-only probe" >>"$TMP/meta"
  missing=$((missing + 1))
fi

while IFS="$(printf '\t')" read -r dim bin sev cmd; do
  [ -n "${dim:-}" ] || continue
  if ! command -v "$bin" >/dev/null 2>&1; then
    printf '# tool=%s status=missing dimensions=%s\n' "$bin" "$dim" >>"$TMP/meta"
    missing=$((missing + 1))
    continue
  fi
  printf '# tool=%s status=ran dimensions=%s\n' "$bin" "$dim" >>"$TMP/meta"
  ran=$((ran + 1))
  sh -c "$cmd" >"$TMP/out" 2>&1 || true
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    file=$(printf '%s' "$line" | sed -n 's/^\([^ :][^ :]*\):[0-9][0-9]*[: 	].*/\1/p')
    lno=$(printf '%s' "$line" | sed -n 's/^[^ :][^ :]*:\([0-9][0-9]*\)[: 	].*/\1/p')
    [ -n "$file" ] || file="-"
    [ -n "$lno" ] || lno=0
    # A diagnostic may itself contain '|' (regex alternations, table output,
    # shell snippets). Escaping it as '\\|' in the two free-text fields keeps
    # the field count fixed at five for any consumer, naive splitter included.
    file=$(printf '%s' "$file" | sed 's/|/\\|/g')
    msg=$(printf '%s' "$line" | sed 's/|/\\|/g')
    printf '%s|%s|%s|%s|%s\n' "$sev" "$file" "$lno" "$dim" "$msg" >>"$TMP/findings"
  done <"$TMP/out"
done <"$TMP/tools"

printf "# deferred=%s reason=%s\n" \
  "org-fit-a11y-semantics-and-keyboard" "screen-reader and keyboard traversal need a rendered surface" \
  "org-fit-a11y-adaptive-presentation" "zoom/reflow matrix needs a browser" \
  "org-fit-performance-budget-regression" "budget assertions need a production-shaped build" >>"$TMP/meta"

cat "$TMP/meta"
cat "$TMP/findings"
printf '# summary tools_ran=%s tools_missing=%s findings=%s\n' \
  "$ran" "$missing" "$(wc -l <"$TMP/findings" | tr -d ' ')"
exit 0
