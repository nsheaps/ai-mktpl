#!/bin/sh
# check-skill.sh — programmatic conformance checks for Claude Code Skills.
#
# Usage:
#   check-skill.sh [--portable] [--quiet] PATH [PATH...]
#
#   PATH  a SKILL.md file, or a directory searched recursively for SKILL.md.
#         Symlinks are followed (find -L) so symlinked skill trees are covered.
#
# Options:
#   --portable  also enforce the 6-field Agent Skills spec whitelist (SK021).
#               Use for skills that may be uploaded/packaged to claude.ai.
#   --quiet     findings only, no summary lines.
#
# Output: one finding per line on stdout:
#   SEVERITY|FILE|LINE|CHECK_ID|MESSAGE
# SEVERITY is P0, P1 or P2. LINE is 0 when a finding has no single line.
# Summary lines are prefixed with '#'.
#
# Exit: 0 = no P0 findings, 1 = at least one P0 finding, 2 = usage error.
#
# Check IDs are stable. See references/authoring-standard.md for the rationale
# behind each one.

set -u

KNOWN_KEYS="name description license compatibility metadata allowed-tools when_to_use argument-hint arguments disable-model-invocation user-invocable disallowed-tools model effort context agent background hooks paths shell"
SPEC_KEYS="name description license compatibility metadata allowed-tools"

PORTABLE=0
QUIET=0
P0=0
P1=0
P2=0
FILES_CHECKED=0

usage() {
	echo "usage: check-skill.sh [--portable] [--quiet] PATH [PATH...]" >&2
	exit 2
}

finding() {
	# finding SEVERITY FILE LINE ID MESSAGE
	printf '%s|%s|%s|%s|%s\n' "$1" "$2" "$3" "$4" "$5"
	case "$1" in
	P0) P0=$((P0 + 1)) ;;
	P1) P1=$((P1 + 1)) ;;
	P2) P2=$((P2 + 1)) ;;
	esac
}

# Emit "key<TAB>value" for each top-level frontmatter key. Folds block scalars
# and list items into a single space-joined value, which is enough for the
# length/format checks below.
fm_pairs() {
	awk '
    NR==1 { if ($0 !~ /^---[ \t]*$/) exit; next }
    /^---[ \t]*$/ { exit }
    /^[A-Za-z_][A-Za-z0-9_.-]*:/ {
      if (key != "") print key "\t" val
      key = $0; sub(/:.*/, "", key)
      val = $0; sub(/^[^:]*:[ \t]*/, "", val)
      if (val ~ /^[>|][-+0-9]*$/) val = ""
      next
    }
    /^[ \t]+[^ \t]/ || /^-[ \t]/ {
      if (key == "") next
      line = $0; sub(/^[ \t]*/, "", line)
      val = (val == "" ? line : val " " line)
    }
    END { if (key != "") print key "\t" val }
  ' "$1"
}

fm_get() { printf '%s\n' "$FM" | awk -F'\t' -v k="$1" '$1==k {print $2; exit}'; }
fm_has() { printf '%s\n' "$FM" | awk -F'\t' -v k="$1" '$1==k {f=1} END {exit !f}'; }

# Line number where the frontmatter block ends (0 if never terminated).
fm_end_line() {
	awk 'NR==1 { if ($0 !~ /^---[ \t]*$/) { print 0; f=1; exit } ; next }
       /^---[ \t]*$/ { print NR; f=1; exit }
       END { if (!f) print 0 }' "$1"
}

check_skill() {
	f=$1
	dir=$(dirname "$f")
	base=$(basename "$dir")
	FILES_CHECKED=$((FILES_CHECKED + 1))

	# --- SK001: frontmatter present ---------------------------------------
	if [ "$(head -n 1 "$f")" != "---" ]; then
		finding P0 "$f" 1 SK001 "no YAML frontmatter (file does not start with ---); skill can never auto-trigger"
		return
	fi

	# --- SK002: frontmatter terminated ------------------------------------
	fmend=$(fm_end_line "$f")
	if [ "$fmend" -eq 0 ]; then
		finding P0 "$f" 1 SK002 "frontmatter block is never closed by a second ---"
		return
	fi

	FM=$(fm_pairs "$f")

	# --- SK023: plain scalar containing ': ' ------------------------------
	# A YAML plain scalar may not contain colon-space; the parse fails and the
	# WHOLE frontmatter block is dropped, so the skill loads with no name and no
	# description and can never trigger. It is invisible on inspection — the
	# line reads perfectly as prose — which is exactly why it needs a check.
	awk -v end="$fmend" '
		NR>1 && NR<end && /^[A-Za-z0-9_-]+:[ \t]/ {
			v=$0; sub(/^[A-Za-z0-9_-]+:[ \t]*/, "", v)
			if (v ~ /^["'\''>|]/) next          # quoted or block scalar: colons are safe
			if (v ~ /: /) print NR "\t" $0
		}' "$f" >"$TMP/colons"
	while IFS="$(printf '\t')" read -r ln raw; do
		[ -n "${ln:-}" ] || continue
		key=$(printf '%s' "$raw" | cut -d: -f1)
		finding P0 "$f" "$ln" SK023 "'$key' is an unquoted plain scalar containing ': '; YAML parsing fails and the ENTIRE frontmatter is dropped — quote the value or replace the colon with a dash"
	done <"$TMP/colons"

	# --- SK009 / SK021: key whitelists ------------------------------------
	printf '%s\n' "$FM" | cut -f1 | while read -r k; do
		[ -n "$k" ] || continue
		case " $KNOWN_KEYS " in
		*" $k "*) ;;
		*) printf 'BAD9\t%s\n' "$k" ;;
		esac
		if [ "$PORTABLE" -eq 1 ]; then
			case " $SPEC_KEYS " in
			*" $k "*) ;;
			*) printf 'BAD21\t%s\n' "$k" ;;
			esac
		fi
	done >"$TMP/keys"
	while IFS="$(printf '\t')" read -r tag k; do
		ln=$(grep -n "^${k}:" "$f" | head -n 1 | cut -d: -f1)
		[ -n "$ln" ] || ln=0
		case "$tag" in
		BAD9) finding P0 "$f" "$ln" SK009 "unknown frontmatter key '$k' (silently ignored by Claude Code, hard error on claude.ai upload)" ;;
		BAD21) finding P1 "$f" "$ln" SK021 "key '$k' is Claude Code-only and breaks portable packaging" ;;
		esac
	done <"$TMP/keys"

	# --- SK003/SK004/SK005: name ------------------------------------------
	name=$(fm_get name)
	name=$(printf '%s' "$name" | sed 's/^["'\'']//;s/["'\'']$//')
	if ! fm_has name || [ -z "$name" ]; then
		finding P0 "$f" 2 SK003 "frontmatter has no 'name'"
	else
		nlen=$(printf '%s' "$name" | wc -c | tr -d ' ')
		if ! printf '%s' "$name" | grep -Eq '^[a-z0-9]+(-[a-z0-9]+)*$' || [ "$nlen" -gt 64 ]; then
			finding P0 "$f" 2 SK004 "name '$name' must be <=64 chars of lowercase a-z0-9 separated by single hyphens"
		fi
		if [ "$name" != "$base" ]; then
			finding P0 "$f" 2 SK005 "name '$name' does not match parent directory '$base'"
		fi
		if printf '%s' "$name" | grep -Eq 'anthropic|claude'; then
			finding P2 "$f" 2 SK020 "name contains a reserved word (anthropic/claude)"
		fi
	fi

	# --- SK006/SK007/SK008/SK014/SK022: description -----------------------
	desc=$(fm_get description)
	if ! fm_has description || [ -z "$desc" ]; then
		finding P0 "$f" 3 SK006 "frontmatter has no non-empty 'description'; nothing is in context at rest"
	else
		dlen=$(printf '%s' "$desc" | wc -c | tr -d ' ')
		wlen=0
		if fm_has when_to_use; then wlen=$(fm_get when_to_use | wc -c | tr -d ' '); fi
		[ "$dlen" -le 1024 ] || finding P0 "$f" 3 SK007 "description is $dlen chars, over the 1024-char spec cap"
		[ $((dlen + wlen)) -le 1536 ] || finding P0 "$f" 3 SK008 "description + when_to_use is $((dlen + wlen)) chars, over the 1536-char listing cap (tail is truncated)"
		# Quoted spans are literal user utterances (trigger phrases); first
		# person inside them is correct, so strip them before judging person.
		if printf '%s' "$desc" | sed 's/"[^"]*"//g' |
			grep -Eqi "(^|[^a-z])(i can|i will|i'll|i'm|you can|you should|you need|you must|your )"; then
			finding P1 "$f" 3 SK014 "description is not third person (first/second-person phrasing found)"
		fi
		if ! printf '%s' "$desc" | grep -Eqi 'use when|use this|trigger phrase|when the user|when asked|invoked'; then
			finding P2 "$f" 3 SK022 "description has no explicit when-to-use or trigger-phrase clause"
		fi
	fi

	# --- SK010/SK011: body length -----------------------------------------
	total=$(wc -l <"$f" | tr -d ' ')
	body=$((total - fmend))
	[ "$body" -le 500 ] || finding P0 "$f" "$total" SK010 "body is $body lines, over the 500-line hard budget (recurring per-session token cost)"
	if [ "$body" -gt 200 ] && [ "$body" -le 500 ]; then
		finding P1 "$f" "$total" SK011 "body is $body lines, over the 200-line org budget; move detail into references/"
	fi

	# --- SK017/SK018: fork wiring -----------------------------------------
	ctx=$(fm_get context)
	if [ "$ctx" != "fork" ]; then
		for k in agent background; do
			if fm_has "$k"; then
				ln=$(grep -n "^${k}:" "$f" | head -n 1 | cut -d: -f1)
				finding P1 "$f" "${ln:-0}" SK017 "'$k:' is only meaningful alongside 'context: fork'"
			fi
		done
	else
		if ! grep -qiE '(return|output) contract|^#+ *returns?\b|returns? (only|exactly|the following)' "$f"; then
			finding P1 "$f" 0 SK018 "context: fork but no return contract found; the parent sees only the return value"
		fi
	fi

	# --- SK012/SK019: outbound references ---------------------------------
	# Markdown links plus org-convention @-includes, relative paths only.
	# Fenced code blocks are stripped first: they hold templates and examples
	# whose [label](url) placeholders are not real references.
	awk '/^[ \t]*```/ {inb = !inb; next} !inb' "$f" >"$TMP/prose"
	# Every link on a line, not just the last: sed's greedy '.*](' would anchor
	# on the final '](' and silently drop earlier links on the same line.
	{
		awk '{
			s = $0
			while (match(s, /\]\([^)]+\)/)) {
				print substr(s, RSTART + 2, RLENGTH - 3)
				s = substr(s, RSTART + RLENGTH)
			}
		}' "$TMP/prose"
		sed -n 's/^@\([^ 	]*\).*/\1/p' "$TMP/prose"
	} | sort -u | while read -r ref; do
		[ -n "$ref" ] || continue
		case "$ref" in
		http://* | https://* | mailto:* | \#* | /*) continue ;;
		esac
		# ${CLAUDE_SKILL_DIR} resolves to this skill's directory at runtime.
		case "$ref" in
		'${CLAUDE_SKILL_DIR}'/*) ref=${ref#'${CLAUDE_SKILL_DIR}'/} ;;
		esac
		# Skip anything still holding a variable or a <placeholder>, and bare
		# words like (url) or (link): those are prose, not paths.
		case "$ref" in
		*'$'* | *'<'* | *'>'*) continue ;;
		esac
		case "$ref" in
		*/* | *.*) ;;
		*) continue ;;
		esac
		ref=${ref%%#*}
		[ -n "$ref" ] || continue
		if [ ! -e "$dir/$ref" ]; then
			ln=$(grep -nF "$ref" "$f" | head -n 1 | cut -d: -f1)
			printf 'MISS\t%s\t%s\n' "${ln:-0}" "$ref"
		fi
		case "$ref" in
		*\\*) printf 'BSLASH\t0\t%s\n' "$ref" ;;
		esac
	done >"$TMP/refs"
	while IFS="$(printf '\t')" read -r tag ln ref; do
		case "$tag" in
		MISS) finding P0 "$f" "$ln" SK012 "referenced path '$ref' does not exist" ;;
		BSLASH) finding P2 "$f" "$ln" SK019 "reference '$ref' uses backslashes; use forward slashes" ;;
		esac
	done <"$TMP/refs"

	# --- SK013/SK015/SK016: bundled resources -----------------------------
	for sub in references scripts assets; do
		[ -d "$dir/$sub" ] || continue
		# Only top-level entries: files nested under a bundled subdirectory are
		# that subdirectory's business, not SKILL.md's.
		find "$dir/$sub" -maxdepth 1 -type f 2>/dev/null | while read -r bf; do
			bn=$(basename "$bf")
			grep -qF "$bn" "$f" || printf 'UNREF\t%s\n' "$bf"
			case "$sub" in
			references)
				bl=$(wc -l <"$bf" | tr -d ' ')
				if [ "$bl" -gt 100 ] && ! head -n 20 "$bf" | grep -qiE 'contents|table of contents'; then
					printf 'NOTOC\t%s\n' "$bf"
				fi
				;;
			scripts)
				# Executable-intent files only; data and schemas living beside
				# them are not scripts.
				case "$bn" in
				*.sh | *.bash | *.py | *.rb | *.pl | *.js | *.ts) ;;
				*.*) continue ;;
				esac
				[ -x "$bf" ] || printf 'NOEXEC\t%s\n' "$bf"
				head -n 1 "$bf" | grep -q '^#!' || printf 'NOSHEBANG\t%s\n' "$bf"
				;;
			esac
		done
	done >"$TMP/bundled"
	while IFS="$(printf '\t')" read -r tag bf; do
		case "$tag" in
		UNREF) finding P1 "$f" 0 SK013 "bundled file '$bf' is never mentioned in SKILL.md; Claude will not find it" ;;
		NOTOC) finding P1 "$bf" 0 SK015 "reference file is over 100 lines with no Contents section in its first 20 lines" ;;
		NOEXEC) finding P1 "$bf" 0 SK016 "script is not executable (chmod +x)" ;;
		NOSHEBANG) finding P1 "$bf" 1 SK016 "script has no shebang line" ;;
		esac
	done <"$TMP/bundled"
}

# ---------------------------------------------------------------------------
targets=""
while [ $# -gt 0 ]; do
	case "$1" in
	--portable) PORTABLE=1 ;;
	--quiet) QUIET=1 ;;
	-h | --help)
		sed -n '2,32p' "$0" | sed 's/^# \{0,1\}//'
		exit 0
		;;
	-*) usage ;;
	*) targets="$targets $1" ;;
	esac
	shift
done
[ -n "$targets" ] || usage

TMP=$(mktemp -d) || exit 2
trap 'rm -rf "$TMP"' EXIT INT TERM

for t in $targets; do
	if [ ! -e "$t" ]; then
		echo "check-skill.sh: no such path: $t" >&2
		exit 2
	fi
done

for t in $targets; do
	if [ -d "$t" ]; then
		find -L "$t" -name SKILL.md -type f 2>/dev/null | sort -u
	elif [ -f "$t" ]; then
		printf '%s\n' "$t"
	else
		echo "check-skill.sh: no such path: $t" >&2
		exit 2
	fi
done | sort -u >"$TMP/targets"

while IFS= read -r f; do
	[ -n "$f" ] && check_skill "$f"
done <"$TMP/targets"

if [ "$QUIET" -eq 0 ]; then
	echo "# files_checked=$FILES_CHECKED p0=$P0 p1=$P1 p2=$P2"
	if [ "$P0" -gt 0 ]; then echo "# verdict=FAIL"; else echo "# verdict=PASS"; fi
fi
[ "$P0" -eq 0 ]
