#!/usr/bin/env bash
#
# unlink.sh - Unlink subcommand for agent-config
#
# Removes symlinks and documentation created by the sync command.
# Auto-discovers all upstream--* symlinks in the target directory.
#
# Usage:
#   agent-config unlink <DIR> [OPTIONS]
#
# Arguments:
#   DIR  Target directory to unlink (required, use '.' for current)
#
# Options:
#   -d, --dry-run      Show what would be done without doing it (default)
#   -n, --no-dry-run   Actually perform the unlink
#   -h, --help         Show help message
#
# Examples:
#   agent-config unlink ~/.claude    # Dry-run: show what would be removed
#   agent-config unlink ~/.claude -n # Actually remove symlinks
#   agent-config unlink .claude -n   # Unlink from project directory
#

set -euo pipefail

# Source stdlib for colors, logging (but not common.sh - we don't need UPSTREAM_FOLDER)
# shellcheck source=../stdlib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../stdlib.sh"

# =============================================================================
# Shared State
# =============================================================================

TARGET_DIR=""
DRY_RUN=true

# =============================================================================
# Unlink Implementation
# =============================================================================

# _find_upstream_symlinks - Find all upstream--* symlinks in a type directory
#
# Usage: _find_upstream_symlinks <type_dir>
#
# Returns: List of symlink paths (one per line)
#
_find_upstream_symlinks() {
    local type_dir="$1"
    [[ ! -d "$type_dir" ]] && return 0

    for item in "$type_dir"/upstream--*; do
        [[ -L "$item" ]] && echo "$item"
    done
}

# _find_upstream_docs - Find all upstream--*.md files in rules directory
#
# Usage: _find_upstream_docs <rules_dir>
#
# Returns: List of doc file paths (one per line)
#
_find_upstream_docs() {
    local rules_dir="$1"
    [[ ! -d "$rules_dir" ]] && return 0

    for item in "$rules_dir"/upstream--*.md; do
        [[ -f "$item" ]] && echo "$item"
    done
}

# _unlink_item - Remove a single symlink or file
#
# Usage: _unlink_item <path> <type>
#
_unlink_item() {
    local path="$1" item_type="$2"
    local name
    name=$(basename "$path")

    if [[ -L "$path" ]]; then
        local link_target
        link_target=$(readlink "$path")
        if [[ "$DRY_RUN" == true ]]; then
            dryrun "Would remove $item_type: $name -> $link_target"
        else
            rm "$path"
            success "Removed $item_type: $name"
        fi
    elif [[ -f "$path" ]]; then
        if [[ "$DRY_RUN" == true ]]; then
            dryrun "Would remove $item_type: $name"
        else
            rm "$path"
            success "Removed $item_type: $name"
        fi
    fi
}

# _scan_and_unlink - Scan target directory and unlink all upstream content
#
# Scans rules/, agents/, commands/ for upstream--* symlinks and docs.
# Sets UNLINK_COUNT global variable with count of items found.
#
_scan_and_unlink() {
    UNLINK_COUNT=0

    # Scan each type directory for symlinks
    for type in rules agents commands; do
        local type_dir="$TARGET_DIR/$type"
        while IFS= read -r symlink; do
            [[ -z "$symlink" ]] && continue
            info "Found in $type/:"
            _unlink_item "$symlink" "symlink"
            ((UNLINK_COUNT++)) || true
        done < <(_find_upstream_symlinks "$type_dir")
    done

    # Scan for documentation files
    while IFS= read -r doc; do
        [[ -z "$doc" ]] && continue
        info "Found doc:"
        _unlink_item "$doc" "doc"
        ((UNLINK_COUNT++)) || true
    done < <(_find_upstream_docs "$TARGET_DIR/rules")

    if [[ $UNLINK_COUNT -eq 0 ]]; then
        info "No upstream symlinks or docs found in $TARGET_DIR"
    fi
}

# =============================================================================
# Help
# =============================================================================

_show_help() {
    cat <<EOF
Usage: agent-config unlink <DIR> [OPTIONS]

Remove symlinks and documentation created by the sync command.
Auto-discovers all upstream--* symlinks in the target directory.

Arguments:
  DIR  Target directory to unlink (required, use '.' for current)

Options:
  -d, --dry-run      Show what would be done without doing it (default)
  -n, --no-dry-run   Actually perform the unlink
  -h, --help         Show this help message

Examples:
  agent-config unlink ~/.claude       # Dry-run: show what would be removed
  agent-config unlink ~/.claude -n    # Actually remove symlinks
  agent-config unlink .claude -n      # Unlink from project .claude directory

What gets removed:
  <DIR>/rules/upstream--*      (symlinks from any source repo)
  <DIR>/agents/upstream--*     (symlinks from any source repo)
  <DIR>/commands/upstream--*   (symlinks from any source repo)
  <DIR>/rules/upstream--*.md   (documentation files)
EOF
}

# =============================================================================
# Main Entry Point
# =============================================================================

# unlink_main - Main entry point for unlink subcommand
#
# Parses arguments and removes sync-created symlinks.
#
# Usage: unlink_main <DIR> [OPTIONS]
#
unlink_main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -d|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -n|--no-dry-run)
                DRY_RUN=false
                shift
                ;;
            -h|--help)
                _show_help
                return 0
                ;;
            -*)
                error "Unknown option: $1"
                error "Run 'agent-config unlink --help' for usage"
                return 1
                ;;
            *)
                # First positional argument is the target directory
                if [[ -z "$TARGET_DIR" ]]; then
                    TARGET_DIR="$1"
                    shift
                else
                    error "Unexpected argument: $1"
                    error "Run 'agent-config unlink --help' for usage"
                    return 1
                fi
                ;;
        esac
    done

    # Require target directory
    if [[ -z "$TARGET_DIR" ]]; then
        error "Missing required argument: <DIR>"
        error "Run 'agent-config unlink --help' for usage"
        return 1
    fi

    # Verify target exists
    if [[ ! -d "$TARGET_DIR" ]]; then
        error "Directory does not exist: $TARGET_DIR"
        return 1
    fi

    # Show header
    info "Target: $TARGET_DIR"
    [[ "$DRY_RUN" == true ]] && dryrun "=== DRY RUN MODE ===" || true

    # Scan and unlink (sets UNLINK_COUNT)
    _scan_and_unlink

    # Show completion message
    if [[ "$DRY_RUN" == true ]]; then
        if [[ "$UNLINK_COUNT" -gt 0 ]]; then
            info "Dry run complete. No changes were made."
            info "To apply these changes, run:"
            info "  agent-config unlink \"$TARGET_DIR\" --no-dry-run"
        fi
    else
        if [[ "$UNLINK_COUNT" -gt 0 ]]; then
            success "Unlink complete! Removed $UNLINK_COUNT item(s)."
        fi
    fi
}
