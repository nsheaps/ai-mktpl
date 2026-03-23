#!/usr/bin/env bash
# Detects if the current project has an in-progress poc-rest-owl-loop workflow
# and reports the current phase status.

set -euo pipefail

PLUGIN_NAME="poc-rest-owl-loop"
source "${CLAUDE_PLUGIN_ROOT}/lib/plugin-config-read.sh"
source "${CLAUDE_PLUGIN_ROOT}/lib/hook-logging.sh"

detect_project() {
  local artifacts_dir
  artifacts_dir="$(plugin_get_config "artifactsDir" "docs/rest-owl")"
  local rest_owl_dir="${CLAUDE_PROJECT_DIR:-$(pwd)}/${artifacts_dir}"

  if [ ! -d "$rest_owl_dir" ]; then
    return 0
  fi

  # Determine which phases have been completed
  local phases=()
  [ -f "$rest_owl_dir/00-intake.md" ] && phases+=("0:intake")
  [ -f "$rest_owl_dir/01-competitive-research.md" ] && phases+=("1:research")
  [ -f "$rest_owl_dir/02-feature-spec.md" ] && phases+=("2:spec")
  [ -f "$rest_owl_dir/03-design-system.md" ] && phases+=("3:design")
  [ -d "$rest_owl_dir/03-mockups" ] && phases+=("3:mockups")
  [ -f "$rest_owl_dir/04-architecture.md" ] && phases+=("4:architecture")
  [ -f "$rest_owl_dir/05-implementation-plan.md" ] && phases+=("5:plan")

  if [ ${#phases[@]} -eq 0 ]; then
    return 0
  fi

  local completed="${phases[*]}"
  hook_log "project detected — completed phases: ${completed}"
  hook_log "Use /poc-rest-owl-loop to resume the workflow"
}

hook_run detect_project
hook_respond
