#!/bin/bash
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

# Colors for output
# TODO use stdlib
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory and repo root TODO use stdlib
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

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
                echo -e "${RED}--target requires a path argument${NC}" >&2
                exit 1
            fi
            ;;
        -D|--dry-run)
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
            echo "  -T, --target PATH  Sync to specified directory (default: \$REPO_ROOT/.claude, detected: $REPO_ROOT/.claude)"
            echo "  -u, --user         Sync to user ~/.claude directory (detected: $HOME/.claude)"
            echo "  -D, --dry-run      Show what would be done without doing it (default)"
            echo "  -n, --no-dry-run   Actually perform the sync"
            echo "  -v, --verbose      Show detailed output"
            echo "  -h, --help         Show this help message"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}" >&2
            exit 1
            ;;
    esac
done

# Determine target directory
if [[ "$TARGET_LEVEL" == "user" ]]; then
    TARGET_DIR="$HOME/.claude"
elif [[ -z "$TARGET_DIR" ]]; then
    # Default: .claude relative to repo root
    TARGET_DIR="$REPO_ROOT/.claude"
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

UPSTREAM_FOLDER=$(derive_upstream_folder "$REPO_ROOT")

# TODO use stdlib
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_verbose() {
    if [[ "$VERBOSE" == true ]]; then
        echo -e "${BLUE}[DEBUG]${NC} $1"
    fi
}

log_dryrun() {
    echo -e "${YELLOW}[DRY]${NC} $1"
}

# Create directory symlink, handling dry-run mode and existing links
# TODO move to stdlib
create_dir_symlink() {
    local source="$1"
    local target="$2"

    # Check if symlink already exists
    if [[ -L "$target" ]]; then
        local existing_target
        existing_target=$(readlink "$target")
        if [[ "$existing_target" == "$source" ]]; then
            log_verbose "Already linked: $target -> $source"
            return 0
        else
            log_error "Symlink exists but points to different target!"
            log_error "  Expected: $source"
            log_error "  Actual:   $existing_target"
            log_error "  Remove the symlink manually or fix the conflict."
            exit 1
        fi
    elif [[ -e "$target" ]]; then
        log_error "Target exists and is not a symlink: $target"
        log_error "  Remove it manually if you want to sync here."
        exit 1
    fi

    if [[ "$DRY_RUN" == true ]]; then
        log_dryrun "Would create: $target -> $source"
        return 0
    fi

    # Create parent directory if needed
    local parent_dir
    parent_dir=$(dirname "$target")
    mkdir -p "$parent_dir"

    # Create the symlink
    ln -s "$source" "$target"
    log_success "Created: $target -> $source"
}

# List existing content in a target directory
list_existing_content() {
    local target_type_dir="$1"
    local type_name="$2"

    if [[ ! -d "$target_type_dir" ]]; then
        log_info "  (no existing $type_name directory)"
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
            log_info "  [symlink] $name -> $link_target"
        elif [[ -d "$item" ]]; then
            local file_count
            file_count=$(find "$item" -name "*.md" -type f 2>/dev/null | wc -l | tr -d ' ')
            log_info "  [dir] $name/ ($file_count .md files)"
        elif [[ -f "$item" ]]; then
            log_info "  [file] $name"
        fi
    done

    if [[ "$has_content" == false ]]; then
        log_info "  (empty directory)"
    fi
}

# Sync a directory by creating a single directory symlink
sync_directory() {
    local source_type="$1"  # rules, agents, or commands
    local source_dir="$REPO_ROOT/$BASE_SYNC_PATH/$source_type"
    local target_type_dir="$TARGET_DIR/$source_type"
    local target_link="$target_type_dir/$UPSTREAM_FOLDER"

    log_info "Syncing $source_type..."

    # Show existing content in target directory
    log_info "Existing $source_type in target:"
    list_existing_content "$target_type_dir" "$source_type"

    if [[ ! -d "$source_dir" ]]; then
        log_verbose "Source directory does not exist: $source_dir"
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
        log_verbose "  -> $rel_path"
        ((count++)) || true
    done < <(find "$source_dir" -name "*.md" -type f -print0)

    log_info "  $count $source_type files available via upstream symlink"
}

# Migrate old file symlinks and clean up stale symlinks
# TODO move to stdlib
migrate_and_cleanup() {
    local target_dir="$TARGET_DIR"
    local source_base="$REPO_ROOT/$BASE_SYNC_PATH"

    log_info "Checking for old file symlinks to migrate..."

    local migrated=0
    local stale=0

    for type in rules agents commands; do
        local upstream_dir="$target_dir/$type/$UPSTREAM_FOLDER"

        # Skip if directory doesn't exist (nothing to clean up)
        if [[ ! -d "$upstream_dir" ]]; then
            continue
        fi

        # If upstream_dir is already a symlink to a directory, it's the new format - skip
        if [[ -L "$upstream_dir" ]]; then
            log_verbose "Already using directory symlink for $type"
            continue
        fi

        # Find all symlinks in the upstream folder (old file-based format)
        while IFS= read -r -d '' symlink; do
            local link_target
            link_target=$(readlink "$symlink")

            # Check if this symlink points to our source directory
            if [[ "$link_target" == "$source_base"* ]]; then
                if [[ "$DRY_RUN" == true ]]; then
                    log_dryrun "Would migrate: $symlink"
                else
                    rm "$symlink"
                    log_info "Migrating: $symlink"
                fi
                ((migrated++)) || true
            elif [[ ! -e "$symlink" ]]; then
                # Stale symlink (target doesn't exist)
                if [[ "$DRY_RUN" == true ]]; then
                    log_dryrun "Would remove stale: $symlink"
                else
                    rm "$symlink"
                    log_verbose "Removed stale: $symlink"
                fi
                ((stale++)) || true
            fi
        done < <(find "$upstream_dir" -type l -print0 2>/dev/null || true)

        # Remove empty directories (cleanup after migration)
        if [[ "$DRY_RUN" != true ]] && [[ -d "$upstream_dir" ]]; then
            find "$upstream_dir" -type d -empty -delete 2>/dev/null || true
            # Remove the upstream dir itself if it's now empty
            if [[ -d "$upstream_dir" ]] && [[ -z "$(ls -A "$upstream_dir" 2>/dev/null)" ]]; then
                rmdir "$upstream_dir" 2>/dev/null || true
            fi
        fi
    done

    if [[ $migrated -gt 0 ]]; then
        log_info "Migrated $migrated old file symlinks"
    fi
    if [[ $stale -gt 0 ]]; then
        log_info "Removed $stale stale symlinks"
    fi
    if [[ $migrated -eq 0 ]] && [[ $stale -eq 0 ]]; then
        log_verbose "No migration or cleanup needed"
    fi
}

# Main
main() {
    local source_path="$REPO_ROOT/$BASE_SYNC_PATH"

    log_info "Source: $source_path"
    log_info "Target: $TARGET_DIR"
    log_info "Upstream folder: $UPSTREAM_FOLDER"

    if [[ "$DRY_RUN" == true ]]; then
        log_warn "=== DRY RUN MODE ==="
    fi

    # First, migrate old file symlinks and clean up stale ones
    migrate_and_cleanup

    # Then sync each type (creates directory symlinks)
    sync_directory "rules"
    sync_directory "agents"
    sync_directory "commands"

    if [[ "$DRY_RUN" == true ]]; then
        log_info "Dry run complete. No changes were made."
    else
        log_success "Sync complete!"
    fi
}

main
