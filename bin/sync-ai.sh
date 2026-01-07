#!/usr/bin/env bash
#
# sync-ai.sh - Sync .ai content to Claude Code directories
#
# Usage:
#   ./bin/sync-ai.sh              # Dry-run: show what would sync to .claude
#   ./bin/sync-ai.sh -n           # Actually sync to .claude directory
#   ./bin/sync-ai.sh --user -n    # Actually sync to user ~/.claude directory
#   ./bin/sync-ai.sh -T /path/dir # Sync to custom target directory
#
# Syncs:
#   .ai/rules/    -> {target}/rules/upstream--{repo-name}/
#   .ai/agents/   -> {target}/agents/upstream--{repo-name}/
#   .ai/commands/ -> {target}/commands/upstream--{repo-name}/
#

set -euo pipefail

# Source stdlib for colors, logging, and ROOT_DIR
# shellcheck source=lib/stdlib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/stdlib.sh"

# Source path configuration
# Customize these to change where content is synced from
BASE_SYNC_PATH=".ai"

# Defaults
TARGET_DIR=""  # Will be set after parsing args
TARGET_LEVEL="custom"  # "user" or "custom"
DRY_RUN=true  # Default to dry-run for safety
VERBOSE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -u|--user)
            TARGET_LEVEL="user"
            shift
            ;;
        -T|--target)
            TARGET_LEVEL="custom"
            if [[ -n "${2:-}" && ! "$2" =~ ^- ]]; then
                TARGET_DIR="$2"
                shift 2
            else
                error "--target requires a path argument"
                exit 1
            fi
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -n|--no-dry-run)
            DRY_RUN=false
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Sync .ai content to Claude Code directories"
            echo ""
            echo "Options:"
            echo "  -T, --target PATH  Sync to specified directory (default: \$ROOT_DIR/.claude, detected: $ROOT_DIR/.claude)"
            echo "  -u, --user         Sync to user ~/.claude directory (detected: $HOME/.claude)"
            echo "  -d, --dry-run      Show what would be done without doing it (default)"
            echo "  -n, --no-dry-run   Actually perform the sync"
            echo "  -v, --verbose      Show detailed output"
            echo "  -h, --help         Show this help message"
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Determine target directory
if [[ "$TARGET_LEVEL" == "user" ]]; then
    TARGET_DIR="$HOME/.claude"
elif [[ -z "$TARGET_DIR" ]]; then
    # Default: .claude relative to repo root
    TARGET_DIR="$ROOT_DIR/.claude"
elif [[ "$TARGET_DIR" != /* ]]; then
    # Relative path: make it absolute relative to CWD
    TARGET_DIR="$(cd "$(pwd)" && cd "$(dirname "$TARGET_DIR")" && pwd)/$(basename "$TARGET_DIR")"
fi

# Derive upstream folder name from path relative to $HOME
# This avoids collisions when syncing from multiple repos
derive_upstream_folder() {
    local repo_path="$1"
    local relative_path

    # Try to make path relative to $HOME
    if [[ "$repo_path" == "$HOME"* ]]; then
        relative_path="${repo_path#"$HOME"/}"
    else
        # Fall back to just the basename if not under $HOME
        relative_path=$(basename "$repo_path")
    fi

    # Replace / with - for folder name
    local folder_name="${relative_path//\//-}"
    echo "upstream--${folder_name}"
}

UPSTREAM_FOLDER=$(derive_upstream_folder "$ROOT_DIR")

# List existing content in a target directory
list_existing_content() {
    local target_type_dir="$1"
    local type_name="$2"

    if [[ ! -d "$target_type_dir" ]]; then
        info "  (no existing $type_name directory)"
        return 0
    fi

    local has_content=false

    # List all items in the directory
    for item in "$target_type_dir"/*; do
        [[ -e "$item" ]] || continue  # Skip if no matches
        has_content=true

        local name
        name=$(basename "$item")

        if [[ -L "$item" ]]; then
            local link_target
            link_target=$(readlink "$item")
            info "  [symlink] $name -> $link_target"
        elif [[ -d "$item" ]]; then
            local file_count
            file_count=$(find "$item" -name "*.md" -type f 2>/dev/null | wc -l | tr -d ' ')
            info "  [dir] $name/ ($file_count .md files)"
        elif [[ -f "$item" ]]; then
            info "  [file] $name"
        fi
    done

    if [[ "$has_content" == false ]]; then
        info "  (empty directory)"
    fi
}

# Sync a directory by creating a single directory symlink
sync_directory() {
    local source_type="$1"  # rules, agents, or commands
    local source_dir="$ROOT_DIR/$BASE_SYNC_PATH/$source_type"
    local target_type_dir="$TARGET_DIR/$source_type"
    local target_link="$target_type_dir/$UPSTREAM_FOLDER"

    info "Syncing $source_type..."

    # Show existing content in target directory
    info "Existing $source_type in target:"
    list_existing_content "$target_type_dir" "$source_type"

    if [[ ! -d "$source_dir" ]]; then
        verbose "Source directory does not exist: $source_dir"
        return 0
    fi

    # Determine the symlink source path
    local link_source
    if [[ "$TARGET_LEVEL" == "user" ]]; then
        # Use absolute path for user-level
        link_source="$source_dir"
    else
        # Use relative path for custom targets (e.g., ../../.ai/rules)
        # From <target>/<type>/upstream--... to .ai/<type>
        link_source="../../$BASE_SYNC_PATH/$source_type"
    fi

    # Create a single directory symlink
    create_dir_symlink "$link_source" "$target_link"

    # List files that will be available through this symlink
    local count=0
    while IFS= read -r -d '' source_file; do
        local rel_path="${source_file#"$source_dir"/}"
        verbose "  -> $rel_path"
        ((count++)) || true
    done < <(find "$source_dir" -name "*.md" -type f -print0)

    info "  $count $source_type files available via upstream symlink"
}

# Migrate old file symlinks and clean up stale symlinks
migrate_and_cleanup() {
    local target_dir="$TARGET_DIR"
    local source_base="$ROOT_DIR/$BASE_SYNC_PATH"

    info "Checking for old file symlinks to migrate..."

    local migrated=0
    local stale=0

    for type in rules agents commands; do
        local type_dir="$target_dir/$type"
        local upstream_dir="$type_dir/$UPSTREAM_FOLDER"

        # Skip if type directory doesn't exist
        if [[ ! -d "$type_dir" ]]; then
            continue
        fi

        # If upstream_dir is already a symlink to a directory, it's the new format
        if [[ -L "$upstream_dir" ]]; then
            verbose "Already using directory symlink for $type"
        fi

        # Find old file symlinks directly in the type directory (not in subdirs)
        # These are symlinks like ~/.claude/rules/bash-scripting.md -> /path/to/.ai/rules/bash-scripting.md
        while IFS= read -r -d '' symlink; do
            local link_target
            link_target=$(readlink "$symlink")

            # Check if this symlink points to our source directory
            if [[ "$link_target" == "$source_base/$type"* ]]; then
                if [[ "$DRY_RUN" == true ]]; then
                    dryrun "Would remove old file symlink: $symlink"
                else
                    rm "$symlink"
                    info "Removed old file symlink: $symlink"
                fi
                ((migrated++)) || true
            elif [[ ! -e "$symlink" ]]; then
                # Stale symlink (target doesn't exist)
                if [[ "$DRY_RUN" == true ]]; then
                    dryrun "Would remove stale: $symlink"
                else
                    rm "$symlink"
                    verbose "Removed stale: $symlink"
                fi
                ((stale++)) || true
            fi
        done < <(find "$type_dir" -maxdepth 1 -type l -print0 2>/dev/null || true)

        # Also check inside old upstream folder if it exists as a directory (not symlink)
        if [[ -d "$upstream_dir" ]] && [[ ! -L "$upstream_dir" ]]; then
            while IFS= read -r -d '' symlink; do
                local link_target
                link_target=$(readlink "$symlink")

                if [[ "$link_target" == "$source_base"* ]]; then
                    if [[ "$DRY_RUN" == true ]]; then
                        dryrun "Would migrate: $symlink"
                    else
                        rm "$symlink"
                        info "Migrating: $symlink"
                    fi
                    ((migrated++)) || true
                fi
            done < <(find "$upstream_dir" -type l -print0 2>/dev/null || true)

            # Remove empty directories after migration
            if [[ "$DRY_RUN" != true ]]; then
                find "$upstream_dir" -type d -empty -delete 2>/dev/null || true
                if [[ -d "$upstream_dir" ]] && [[ -z "$(ls -A "$upstream_dir" 2>/dev/null)" ]]; then
                    rmdir "$upstream_dir" 2>/dev/null || true
                fi
            fi
        fi
    done

    if [[ $migrated -gt 0 ]]; then
        info "Migrated $migrated old file symlinks"
    fi
    if [[ $stale -gt 0 ]]; then
        info "Removed $stale stale symlinks"
    fi
    if [[ $migrated -eq 0 ]] && [[ $stale -eq 0 ]]; then
        verbose "No migration or cleanup needed"
    fi
}

# Main
main() {
    local source_path="$ROOT_DIR/$BASE_SYNC_PATH"

    info "Source: $source_path"
    info "Target: $TARGET_DIR"
    info "Upstream folder: $UPSTREAM_FOLDER"

    if [[ "$DRY_RUN" == true ]]; then
        warn "=== DRY RUN MODE ==="
    fi

    # First, migrate old file symlinks and clean up stale ones
    migrate_and_cleanup

    # Then sync each type (creates directory symlinks)
    sync_directory "rules"
    sync_directory "agents"
    sync_directory "commands"

    if [[ "$DRY_RUN" == true ]]; then
        info "Dry run complete. No changes were made."
    else
        success "Sync complete!"
    fi
}

main
