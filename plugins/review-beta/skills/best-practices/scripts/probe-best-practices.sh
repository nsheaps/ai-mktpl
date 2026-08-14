#!/bin/sh
# probe-best-practices.sh — programmatic pre-filter for the 'best-practices' review family.
#
# Runs each ecosystem's own opinionated linter -- the tool whose maintainers
# decided what idiomatic looks like in that language -- so "is this idiomatic"
# is answered by that community's published rule set rather than by a reviewer's
# taste.
#
# Usage:
#   probe-best-practices.sh [--base REF] [--list] [PATH]
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
# dimensions. That is deliberate: no tool, no finding. "Idiomatic" is the single
# easiest thing for a reviewer to invent -- every codebase looks unidiomatic to
# someone -- so this family in particular must never judge a language whose
# linter did not run. Report the dimension as unavailable instead.
#
# Deliberately NOT run here, because another aspect already owns them and a
# second run would produce duplicate findings the orchestrator has to merge:
# eslint and shellcheck (review-beta:org-fit), go vet, tsc, mypy and semgrep
# (review-beta:correctness), jscpd and knip (review-beta:design).
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
  echo "usage: probe-best-practices.sh [--base REF] [--list] [PATH]" >&2
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
    sed -n '2,50p' "$0" | sed 's/^#\{1,\} \{0,1\}//'
    exit 0
    ;;
  -*) usage ;;
  *) ROOT=$1 ;;
  esac
  shift
done

[ -d "$ROOT" ] || {
  echo "probe-best-practices.sh: no such directory: $ROOT" >&2
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
# must be cheap enough for a review turn. Every row is check-only: no --fix, no
# --write, no formatter that rewrites in place.
TOOLS=$(
  cat <<'TOOLTABLE'
bp-go-idiom	golangci-lint	major	[ -f go.mod ] && golangci-lint run 2>/dev/null | grep -E '^[^ ]+\.go:[0-9]+' || true
bp-rust-idiom	cargo-clippy	major	[ -f Cargo.toml ] && cargo clippy --message-format=short 2>&1 | grep -E '^[^ ]+\.rs:[0-9]+' || true
bp-python-idiom	ruff	major	ruff check --output-format=concise . 2>/dev/null | grep -E '^[^ ]+\.py:[0-9]+' || true
bp-js-idiom	biome	major	biome lint . 2>/dev/null | grep -E '^[^ ]+:[0-9]+' || true
bp-ruby-idiom	rubocop	major	rubocop --format emacs --no-color 2>/dev/null | grep -E '^[^ ]+\.rb:[0-9]+' || true
bp-css-idiom	stylelint	nit	stylelint '**/*.{css,scss}' --formatter unix 2>/dev/null | grep -E '^[^ ]+:[0-9]+' || true
bp-swift-idiom	swiftlint	major	swiftlint lint --quiet --reporter emacs 2>/dev/null | grep -E '^[^ ]+\.swift:[0-9]+' || true
bp-kotlin-idiom	ktlint	major	ktlint --relative --reporter=plain 2>/dev/null | grep -E '^[^ ]+\.kt:[0-9]+' || true
bp-terraform-idiom	tflint	major	tflint --format=compact 2>/dev/null | grep -E '^[^ ]+\.tf:[0-9]+' || true
bp-php-idiom	phpcs	major	phpcs --report=emacs . 2>/dev/null | grep -E '^[^ ]+\.php:[0-9]+' || true
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
# linter here duplicates results the aggregator has partitioned by dimension.
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
  "bp-framework-idiom" "framework-specific rule packs vary per project and are not discoverable from the tree" >>"$TMP/meta"

cat "$TMP/meta"
cat "$TMP/findings"
printf '# summary tools_ran=%s tools_missing=%s findings=%s\n' \
  "$ran" "$missing" "$(wc -l <"$TMP/findings" | tr -d ' ')"
exit 0
