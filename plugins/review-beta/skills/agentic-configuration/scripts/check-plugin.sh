#!/bin/sh
# check-plugin.sh — programmatic conformance checks for the agentic-configuration
# artifacts that are NOT skills: plugin manifests, hook wiring, agents, commands.
#
# Companion to check-skill.sh, which owns SKILL.md. Same output contract, so a
# reviewer can concatenate both streams and adjudicate one list.
#
# Usage:
#   check-plugin.sh [--quiet] PATH [PATH...]
#
#   PATH  a plugin directory (searched for .claude-plugin/plugin.json,
#         hooks/hooks.json, agents/*.md, commands/*.md), or any one of those
#         files directly.
#
# Options:
#   --quiet  findings only, no summary lines.
#
# Output: one finding per line on stdout:
#   SEVERITY|FILE|LINE|CHECK_ID|MESSAGE
# SEVERITY is P0, P1 or P2. LINE is 0 when a finding has no single line.
# Summary lines are prefixed with '#'.
#
# Exit: 0 = no P0 findings, 1 = at least one P0 finding, 2 = usage error.
#
# Every check below encodes a rule that is written down somewhere in this repo,
# not a preference. The rule's home is named in the message so a disputed
# finding can be settled by reading the source rather than by argument.
#
# Check ID prefixes: PL = plugin manifest, HK = hooks, AG = agents, CM = commands.

set -u

QUIET=0

usage() {
  echo "usage: check-plugin.sh [--quiet] PATH [PATH...]" >&2
  exit 2
}

# Emits only. The severity tally is computed from the buffered output at the end
# of the file, for the reason documented there: a counter incremented inside
# walk()'s find|while subshells never survives back to the parent.
finding() {
  printf '%s|%s|%s|%s|%s\n' "$1" "$2" "$3" "$4" "$5"
}

have_jq() { command -v jq >/dev/null 2>&1; }

# Line number of the first occurrence of a literal key in a JSON file, for
# anchoring a finding. Always prints a number: 0 when not found, because the
# finding is still real and the report needs a parseable LINE field.
key_line() {
  ln=$(grep -nF "\"$2\"" "$1" 2>/dev/null | head -n 1 | cut -d: -f1)
  printf '%s' "${ln:-0}"
}

# --- plugin.json -----------------------------------------------------------
check_plugin_json() {
  f=$1
  echo "# checked=$f"

  if ! have_jq; then
    finding P2 "$f" 0 PL000 "jq is not installed; plugin.json checks are UNAVAILABLE and produced zero findings"
    return
  fi
  if ! jq -e . "$f" >/dev/null 2>&1; then
    finding P0 "$f" 1 PL004 "plugin.json is not valid JSON; Claude Code cannot load the plugin"
    return
  fi

  # PL001/PL002: required manifest fields (plugins/CLAUDE.md "Plugin.json Required Fields")
  for k in name version description; do
    jq -e --arg k "$k" 'has($k) and (.[$k] | type == "string") and (.[$k] | length > 0)' "$f" >/dev/null 2>&1 ||
      finding P0 "$f" "$(key_line "$f" "$k")" PL001 "plugin.json has no non-empty '$k' (required — plugins/CLAUDE.md)"
  done
  jq -e 'has("author")' "$f" >/dev/null 2>&1 ||
    finding P1 "$f" 0 PL002 "plugin.json has no 'author' (conventional for this marketplace — plugins/CLAUDE.md)"

  # PL003: the duplicate-hook-load bug. Declaring the auto-discovered path
  # makes Claude Code load hooks.json twice, one ERROR per hook per session.
  hooks=$(jq -r '.hooks // empty' "$f" 2>/dev/null)
  case "$hooks" in
  ./hooks/hooks.json | hooks/hooks.json)
    finding P0 "$f" "$(key_line "$f" hooks)" PL003 "plugin.json declares 'hooks' at the auto-discovered path; remove the field or hooks.json loads twice (.claude/rules/plugin-hooks-organization.md)"
    ;;
  esac

  # PL005: manifest name must match the plugin directory, or the data dir
  # ({plugin-name}-{marketplace}) and every cross-plugin path break.
  name=$(jq -r '.name // empty' "$f" 2>/dev/null)
  # Resolved with cd/pwd, not basename alone: a relative invocation like
  # `check-plugin.sh .` makes the plugin root literally "." and every manifest
  # would be reported as mis-named.
  pdir=$(basename "$(CDPATH= cd -- "$(dirname "$(dirname "$f")")" && pwd)")
  if [ -n "$name" ] && [ "$name" != "$pdir" ]; then
    finding P1 "$f" "$(key_line "$f" name)" PL005 "plugin.json name '$name' does not match its directory '$pdir'; the data dir is {plugin-name}-{marketplace} (.claude/rules/shared-libs.md)"
  fi

  # PL006: a plugin with no README is undiscoverable in the marketplace listing.
  [ -f "$(dirname "$(dirname "$f")")/README.md" ] ||
    finding P2 "$f" 0 PL006 "plugin has no README.md at its root (required — .claude/rules/plugin-development.md)"
}

# --- hooks.json ------------------------------------------------------------
check_hooks_json() {
  f=$1
  echo "# checked=$f"
  proot=$(dirname "$(dirname "$f")")

  if ! have_jq; then
    finding P2 "$f" 0 HK000 "jq is not installed; hooks.json checks are UNAVAILABLE and produced zero findings"
    return
  fi
  if ! jq -e . "$f" >/dev/null 2>&1; then
    finding P0 "$f" 1 HK002 "hooks.json is not valid JSON; no hook in this plugin will load"
    return
  fi

  # HK001 was retired, and the id is not reused. It flagged PreToolUse,
  # PostToolUse, PostToolUseFailure and PermissionRequest in a plugin hooks.json
  # as silently dead, citing the "Bug -- does not fire" rows in plugins/CLAUDE.md
  # (empirically confirmed there on v2.1.128 CLI, 2026-05-19).
  #
  # That is no longer true. On v2.1.231, a plugin loaded with `--plugin-dir` and
  # declaring all four events fired PreToolUse three times, PostToolUse once and
  # PostToolUseFailure once across three Bash calls, while the same session run
  # without the plugin produced no hook invocations at all. PermissionRequest was
  # not observed, because no call in that run reached a permission prompt -- so it
  # is untested, not disproven, and plugins/CLAUDE.md now says exactly that.
  #
  # The check shipped testing `has($e)` at the top level while all 27 hooks.json
  # in this marketplace nest under `.hooks`, so it never fired. Fixing the nesting
  # would have turned it on against 15 plugins whose hooks demonstrably work, and
  # advised moving them to settings.json. A check that fires on everything is no
  # better than one that fires on nothing; the rule it enforced expired.

  # HK003/HK004: a command referencing a missing script fails at hook time,
  # which is the worst place to discover it.
  #
  # The exec bit only matters when the script is invoked DIRECTLY. The common
  # form in this marketplace is `bash ${CLAUDE_PLUGIN_ROOT}/...`, where mode
  # 0644 is perfectly fine — flagging it would be a false positive, and a
  # false positive costs the reader more than the check saves. So HK004 fires
  # only when the plugin-root path is itself the first token of the command.
  jq -r '[.. | objects | .command? // empty] | .[]' "$f" 2>/dev/null |
    while IFS= read -r cmd; do
      [ -n "$cmd" ] || continue
      first=${cmd%% *}
      printf '%s\n' "$cmd" | grep -oE '\$\{CLAUDE_PLUGIN_ROOT\}/[^ "'"'"']+' | sort -u |
        while read -r ref; do
          rel=${ref#'${CLAUDE_PLUGIN_ROOT}'/}
          if [ ! -e "$proot/$rel" ]; then
            finding P1 "$f" "$(key_line "$f" "$rel")" HK003 "hook command references '$rel', which does not exist in the plugin"
            continue
          fi
          # Direct invocation: the path is the command itself, not an
          # argument to an interpreter.
          if [ "$first" = "$ref" ] && [ ! -x "$proot/$rel" ]; then
            finding P1 "$f" "$(key_line "$f" "$rel")" HK004 "hook script '$rel' is executed directly but is not executable; the hook will fail at run time"
          fi
        done
    done
}

# --- agents/ and commands/ -------------------------------------------------
# Both are markdown-with-frontmatter. A missing name or description does not
# error — the entry is silently unusable, which is why these are P0.
check_md_frontmatter() {
  f=$1
  kind=$2 # agent | command
  echo "# checked=$f"
  case "$kind" in
  agent) idp=AG ;;
  *) idp=CM ;;
  esac

  if ! head -n 1 "$f" | grep -q '^---[ 	]*$'; then
    finding P0 "$f" 1 "${idp}001" "$kind file has no YAML frontmatter; Claude Code cannot register it"
    return
  fi
  fm=$(awk 'NR==1{next} /^---[ \t]*$/{exit} {print}' "$f")

  printf '%s\n' "$fm" | grep -qE '^description:[ \t]*[^ \t]' ||
    finding P0 "$f" 2 "${idp}002" "$kind frontmatter has no non-empty 'description'; it will never be selected"

  if [ "$kind" = agent ]; then
    printf '%s\n' "$fm" | grep -qE '^name:[ \t]*[^ \t]' ||
      finding P0 "$f" 2 AG002 "agent frontmatter has no non-empty 'name'"
    n=$(printf '%s\n' "$fm" | sed -n 's/^name:[ \t]*//p' | head -n 1 | tr -d '"'"'"' \t\r')
    b=$(basename "$f" .md)
    if [ -n "$n" ] && [ "$n" != "$b" ]; then
      finding P1 "$f" 2 AG003 "agent name '$n' does not match its filename '$b.md' (marketplace convention, not a written rule — Claude Code registers agents by the frontmatter name, so a mismatch misleads readers rather than breaking loading)"
    fi
  fi
}

# --- dispatch --------------------------------------------------------------
walk() {
  p=$1
  p=${p%/} # a trailing slash doubles up in the FILE field and breaks file:line jumps
  if [ -f "$p" ]; then
    case "$(basename "$p")" in
    plugin.json) check_plugin_json "$p" ;;
    hooks.json) check_hooks_json "$p" ;;
    *.md)
      case "$p" in
      */agents/*) check_md_frontmatter "$p" agent ;;
      */commands/*) check_md_frontmatter "$p" command ;;
      *) echo "# skipped (not a recognized artifact): $p" ;;
      esac
      ;;
    *) echo "# skipped (not a recognized artifact): $p" ;;
    esac
    return
  fi
  [ -d "$p" ] || {
    echo "check-plugin.sh: no such path: $p" >&2
    return
  }
  [ -f "$p/.claude-plugin/plugin.json" ] && check_plugin_json "$p/.claude-plugin/plugin.json"
  [ -f "$p/hooks/hooks.json" ] && check_hooks_json "$p/hooks/hooks.json"
  find -L "$p/agents" -name '*.md' -type f 2>/dev/null | sort | while read -r a; do
    check_md_frontmatter "$a" agent
  done
  find -L "$p/commands" -name '*.md' -type f 2>/dev/null | sort | while read -r c; do
    check_md_frontmatter "$c" command
  done
  return 0
}

# Flags are rotated out of "$@" and paths rotated to the back, matching
# check-skill.sh. `break`ing at the first non-flag made argument ORDER
# significant — a trailing `--quiet` was re-read as a path — which is the
# invocation the README's "concatenate both streams" advice invites. The
# rotation also survives paths containing spaces, and closes the single-dash
# gap where `--*)` let `-x` fall through and be treated as a path.
[ $# -gt 0 ] || usage
argc=$#
npaths=0
while [ "$argc" -gt 0 ]; do
  arg=$1
  shift
  argc=$((argc - 1))
  case "$arg" in
  --quiet) QUIET=1 ;;
  # Asking for help is not a usage error, so it prints the header to stdout and
  # exits 0 — same contract as check-skill.sh, which this file claims to share.
  -h | --help)
    sed -n '2,29p' "$0" | sed 's/^# \{0,1\}//'
    exit 0
    ;;
  -*) usage ;;
  *)
    set -- "$@" "$arg"
    npaths=$((npaths + 1))
    ;;
  esac
done
[ "$npaths" -gt 0 ] || usage

# There are no severity counters, deliberately. The find|while loops in walk()
# run in subshells, so any counter they bumped would be lost by the time control
# returns here; two of them lived in this file for a while, silently wrong and
# never read. Buffering the findings and tallying the buffer is the only way the
# summary and the exit status can be telling the truth — an exit 0 that was
# really a P0 is worse than no check. (check-skill.sh keeps its counters and is
# right to: it reads its targets from a redirect, so finding() runs in the
# parent shell there.)
# Validated up front, exactly as check-skill.sh does. Reporting a mistyped path
# as "0 findings, verdict=PASS, exit 0" is the silent zero this whole plugin
# argues against — the caller cannot tell a clean plugin from a path that was
# never read. A usage error is exit 2, not a pass.
for p in "$@"; do
  [ -e "$p" ] || {
    echo "check-plugin.sh: no such path: $p" >&2
    exit 2
  }
done

OUT=$(mktemp "${TMPDIR:-/tmp}/check-plugin.XXXXXX") || exit 2
trap 'rm -f "$OUT"' EXIT INT TERM

for p in "$@"; do walk "$p"; done >"$OUT"
# The per-file markers are tallied, not printed: they exist so the summary can
# distinguish "read 40 files, found nothing" from "read nothing" -- the same
# distinction HK000/PL000 draw for a missing jq, and the one a bare `findings=0`
# cannot. A counter variable cannot do this job: walk()'s find|while loops run
# in subshells, so increments made inside them are lost, which is why the
# previous FILES_CHECKED was both silently wrong and never emitted.
grep -v '^# checked=' "$OUT" || true

n0=$(awk -F'|' '$1=="P0"' "$OUT" | wc -l | tr -d ' ')
n1=$(awk -F'|' '$1=="P1"' "$OUT" | wc -l | tr -d ' ')
n2=$(awk -F'|' '$1=="P2"' "$OUT" | wc -l | tr -d ' ')
nf=$(awk '/^#/{next} {n++} END{print n+0}' "$OUT")
nc=$(grep -c '^# checked=' "$OUT" || true)

[ "$QUIET" -eq 1 ] || {
  echo "# files_checked=$nc findings=$nf p0=$n0 p1=$n1 p2=$n2"
  echo "# verdict=$([ "$n0" -eq 0 ] && echo PASS || echo FAIL)"
}

[ "$n0" -eq 0 ] || exit 1
exit 0
