#!/usr/bin/env bash
#
# common.sh - Shared configuration and helpers for agent-config
#
# This file contains:
#   - Configuration variables (paths, naming conventions)
#   - Helper functions used across subcommands
#
# Usage:
#   source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
#

# Prevent multiple inclusion
[[ -n "${_AGENT_CONFIG_COMMON_LOADED:-}" ]] && return 0
_AGENT_CONFIG_COMMON_LOADED=1

# Source stdlib for colors, logging, ROOT_DIR, create_dir_symlink
# shellcheck source=../stdlib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../stdlib.sh"

# =============================================================================
# Configuration
# =============================================================================

# Base path for AI configuration content (relative to repo root)
readonly BASE_SYNC_PATH=".ai"

# Derive upstream folder name from repo path
# This creates a unique identifier like "upstream--src-nsheaps-ai"
# to avoid collisions when syncing from multiple repos
_derive_upstream_folder() {
    local folder="upstream--${ROOT_DIR#"$HOME"/}"
    echo "${folder//\//-}"
}
readonly UPSTREAM_FOLDER="$(_derive_upstream_folder)"

# =============================================================================
# Shared State (set by subcommands)
# =============================================================================

# Target directory for sync operations
# Set via --target or --user flags, defaults to $ROOT_DIR/.claude
TARGET_DIR=""

# Dry-run mode - if true, show what would happen without making changes
DRY_RUN=true

# =============================================================================
# Helper Functions
# =============================================================================

# maybe_rm - Remove a file with dry-run support
#
# Usage: maybe_rm <file> <reason>
#
# Arguments:
#   file   - Path to file to remove
#   reason - Human-readable reason for removal (shown in output)
#
maybe_rm() {
    local file="$1" reason="$2"
    if [[ "$DRY_RUN" == true ]]; then
        dryrun "             ^ would be removed ($reason)"
    else
        rm "$file"
        info "             ^ removed ($reason)"
    fi
}

# list_existing_content - List and optionally migrate content in a target directory
#
# Lists all items in the target directory, showing their type (symlink, dir, file).
# For symlinks, checks if they should be migrated (point to our source) or are stale.
#
# Usage: list_existing_content <target_type_dir> <type_name> <source_base>
#
# Arguments:
#   target_type_dir - Directory to list (e.g., ~/.claude/rules)
#   type_name       - Type name for display (e.g., "rules")
#   source_base     - Base path of source content (e.g., /path/to/repo/.ai)
#
list_existing_content() {
    local target_type_dir="$1" type_name="$2" source_base="$3"

    if [[ ! -d "$target_type_dir" ]]; then
        info "  (no existing $type_name directory)"
        return 0
    fi

    local has_content=false
    for item in "$target_type_dir"/*; do
        [[ -e "$item" || -L "$item" ]] || continue
        has_content=true
        local name=$(basename "$item")

        if [[ -L "$item" ]]; then
            local link_target=$(readlink "$item")
            info "  [symlink] $name -> $link_target"

            # Check if this symlink should be migrated (points to our source)
            if [[ "$link_target" == "$source_base/$type_name"* ]]; then
                maybe_rm "$item" "old file symlink"
            elif [[ ! -e "$item" ]]; then
                maybe_rm "$item" "stale symlink"
            fi
        elif [[ -d "$item" ]]; then
            local count=$(find "$item" -name "*.md" -type f 2>/dev/null | wc -l | tr -d ' ')
            info "  [dir] $name/ ($count .md files)"
        else
            info "  [file] $name"
        fi
    done

    [[ "$has_content" == false ]] && info "  (empty directory)" || true
}

# sync_type_directory - Sync a single content type by creating a directory symlink
#
# Creates a symlink from <target>/<type>/<upstream-folder> to <source>/<type>
# Uses absolute paths for user config (~/.claude), relative paths for project config.
#
# Usage: sync_type_directory <type>
#
# Arguments:
#   type - Content type to sync (rules, agents, commands)
#
# Requires:
#   TARGET_DIR, ROOT_DIR, BASE_SYNC_PATH, UPSTREAM_FOLDER to be set
#
sync_type_directory() {
    local source_type="$1"
    local source_dir="$ROOT_DIR/$BASE_SYNC_PATH/$source_type"
    local target_type_dir="$TARGET_DIR/$source_type"
    local target_link="$target_type_dir/$UPSTREAM_FOLDER"

    info "Syncing $source_type..."
    info "Existing $source_type in target:"
    list_existing_content "$target_type_dir" "$source_type" "$ROOT_DIR/$BASE_SYNC_PATH"

    [[ ! -d "$source_dir" ]] && return 0

    # Use absolute path for user config, relative for project config
    local link_source
    if [[ "$TARGET_DIR" == "$HOME/.claude" ]]; then
        link_source="$source_dir"
    else
        link_source="../../$BASE_SYNC_PATH/$source_type"
    fi

    create_dir_symlink "$link_source" "$target_link"

    local count=$(find "$source_dir" -name "*.md" -type f | wc -l | tr -d ' ')
    info "  $count $source_type files available via upstream symlink"
}
