#!/usr/bin/env bash
# Capture the identity of the Claude Code binary you are extracting from.
# EVERY extraction MUST record this — a command/skill reproduced from the binary
# is only meaningful next to the exact build it came out of.
#
# Prints a provenance stamp to stdout:
#   version, git sha, build time, binary path, sha256 of the binary.
#
# Usage:
#   binary-version.sh                 # print stamp to stdout
#   binary-version.sh >> PROVENANCE.md
set -euo pipefail

CLAUDE_BIN="${CLAUDE_BIN:-$(readlink -f "$(command -v claude)")}"

# `claude --version` prints e.g. "2.1.223 (Claude Code)".
version="$(claude --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1 || true)"

# The compiled binary embeds VERSION / GIT_SHA / BUILD_TIME markers near ccVersion.
git_sha="$(strings -n 8 "$CLAUDE_BIN" | grep -oE 'GIT_SHA[":= ]+[0-9a-f]{40}' | grep -oE '[0-9a-f]{40}' | head -n1 || true)"
build_time="$(strings -n 8 "$CLAUDE_BIN" | grep -oE 'BUILD_TIME[":= ]+[0-9TZ:.-]+' | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:.Z-]+' | head -n1 || true)"
sha256="$(sha256sum "$CLAUDE_BIN" | awk '{print $1}')"

cat <<EOF
- claude version: ${version:-unknown}
- git sha:        ${git_sha:-unknown}
- build time:     ${build_time:-unknown}
- binary path:    ${CLAUDE_BIN}
- binary sha256:  ${sha256}
- extracted on:   $(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF
