#!/usr/bin/env bash
# Detects if the current project has an in-progress rest-owl workflow
# and reports the current phase status.

set -euo pipefail

REST_OWL_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}/docs/rest-owl"

if [ ! -d "$REST_OWL_DIR" ]; then
  exit 0
fi

# Determine which phases have been completed
phases=()
[ -f "$REST_OWL_DIR/00-intake.md" ] && phases+=("0:intake")
[ -f "$REST_OWL_DIR/01-competitive-research.md" ] && phases+=("1:research")
[ -f "$REST_OWL_DIR/02-feature-spec.md" ] && phases+=("2:spec")
[ -f "$REST_OWL_DIR/03-design-system.md" ] && phases+=("3:design")
[ -d "$REST_OWL_DIR/03-mockups" ] && phases+=("3:mockups")
[ -f "$REST_OWL_DIR/04-architecture.md" ] && phases+=("4:architecture")
[ -f "$REST_OWL_DIR/05-implementation-plan.md" ] && phases+=("5:plan")

if [ ${#phases[@]} -eq 0 ]; then
  exit 0
fi

completed="${phases[*]}"
echo "📦 rest-owl project detected — completed phases: ${completed}"
echo "   Use /rest-owl to resume the workflow"
