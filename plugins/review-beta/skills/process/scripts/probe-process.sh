#!/bin/sh
# probe-process.sh — programmatic pre-filter for the 'process' review family.
#
# Computes the diff- and repo-state signals that decide most of the process family -- change size, commit hygiene, workflow validity, merge gating, release consistency -- from git and the GitHub API.
#
# Usage:
#   probe-process.sh [--base REF] [--list] [PATH]
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
	echo "usage: probe-process.sh [--base REF] [--list] [PATH]" >&2
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
		sed -n '2,45p' "$0" | sed 's/^#\{1,\} \{0,1\}//'
		exit 0
		;;
	-*) usage ;;
	*) ROOT=$1 ;;
	esac
	shift
done

[ -d "$ROOT" ] || {
	echo "probe-process.sh: no such directory: $ROOT" >&2
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
TOOLS=$(
	cat <<'TOOLTABLE'
process-change-size	git	major	git diff --numstat "$BASE"...HEAD 2>/dev/null | awk -F'\t' '$1 != "-" { a += $1; d += $2; f++ } END { if (f > 0 && (a + d) > 400) printf "-:0: diff is %d files, %d added, %d deleted lines (over the 400-line review-attention threshold)\n", f, a, d }' || true
process-commit-hygiene	commitlint	minor	commitlint --from "$BASE" --to HEAD 2>&1 | grep -E '^ *. \[' || true
process-commit-hygiene	git	minor	git log --format='%h %s' "$BASE"..HEAD 2>/dev/null | grep -Ev ' (feat|fix|chore|docs|refactor|test|build|ci|perf|style|revert)(\(.+\))?!?: ' | sed 's/^/-:0: non-conventional commit subject: /' || true
process-merge-gating,process-ci-local-parity	actionlint	blocker	actionlint 2>/dev/null | grep -E '^[^ ]+\.ya?ml:[0-9]+' || true
process-merge-gating,process-review-authority	gh	blocker	gh pr checks --json name,state 2>/dev/null | grep -E '"state":"(FAILURE|CANCELLED)"' || true
process-release-mechanics	semantic-release	major	semantic-release --dry-run --no-ci 2>&1 | grep -E 'ERR|error' || true
process-defect-feedback-loop,process-rollback-path	git	major	[ -f .review/risk-paths.yaml ] && sed -n 's/^ *- *//p' .review/risk-paths.yaml > "$TMP/rp" && git diff --name-only "$BASE"...HEAD 2>/dev/null | grep -F -f "$TMP/rp" 2>/dev/null | sed 's|$|:0: touches a declared risk path; rollback path must be stated|'; rm -f "$TMP/rp"
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
	"process-load-capacity-validation" "load stages are a CI job, not a review turn" \
	"process-operational-readiness" "promtool rule tests need the monitoring repo" \
	"process-flaky-test-policy" "flake rate needs CI history across runs" >>"$TMP/meta"

cat "$TMP/meta"
cat "$TMP/findings"
printf '# summary tools_ran=%s tools_missing=%s findings=%s\n' \
	"$ran" "$missing" "$(wc -l <"$TMP/findings" | tr -d ' ')"
exit 0
