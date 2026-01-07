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

# List existing content in a target directory and handle migration
# Args: target_type_dir type_name source_base
# Sets MIGRATED_COUNT as side effect
list_existing_content() {
    local target_type_dir="$1"
    local type_name="$2"
    local source_base="$3"

    MIGRATED_COUNT=0

    if [[ ! -d "$target_type_dir" ]]; then
        info "  (no existing $type_name directory)"
        return 0
    fi

    local has_content=false

    # List all items in the directory
    for item in "$target_type_dir"/*; do
        [[ -e "$item" ]] || [[ -L "$item" ]] || continue  # Skip if no matches (but keep broken symlinks)
        has_content=true

        local name
        name=$(basename "$item")

        if [[ -L "$item" ]]; then
            local link_target
            link_target=$(readlink "$item")
            info "  [symlink] $name -> $link_target"

            # Check if this symlink should be migrated (points to our source)
            if [[ "$link_target" == "$source_base/$type_name"* ]]; then
                if [[ "$DRY_RUN" == true ]]; then
                    dryrun "             ^ would be removed (old file symlink)"
                else
                    rm "$item"
                    info "             ^ removed (old file symlink)"
                fi
                ((MIGRATED_COUNT++)) || true
            elif [[ ! -e "$item" ]]; then
                # Stale symlink
                if [[ "$DRY_RUN" == true ]]; then
                    dryrun "             ^ would be removed (stale symlink)"
                else
                    rm "$item"
                    verbose "             ^ removed (stale symlink)"
                fi
                ((MIGRATED_COUNT++)) || true
            fi
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

# Generate autogenerated rules documentation file
# This file provides guidance about the synced content
generate_rules_doc() {
    local target_rules_dir="$TARGET_DIR/rules"
    local doc_file="$target_rules_dir/$UPSTREAM_FOLDER.md"
    local timestamp
    timestamp=$(date -u +"%Y-%m-%d %H:%M:%S UTC")

    local content
    content=$(cat <<EOF
<!-- this file is autogenerated. DO NOT EDIT! -->
<!-- last updated: $timestamp -->

WARNING: You have autoconfigured rules, agents, and commands. These paths are managed by automation. Do not edit them directly.

Strongly consider making any changes at the source location instead of within existing or new files managed outside of the symlink from the target location. Doing so helps ensure that your changes are preserved and correctly propagated, and re-usable by future sessions and others in the organization.

- **Source**: $ROOT_DIR
- **Target**: $TARGET_DIR

| Type     | Source                        | Symlinked From               |
|----------|-------------------------------|------------------------------|
| Rules    | \`<source>/$BASE_SYNC_PATH/rules/\`    | \`<target>/rules/$UPSTREAM_FOLDER\`    |
| Commands | \`<source>/$BASE_SYNC_PATH/commands/\` | \`<target>/commands/$UPSTREAM_FOLDER\` |
| Agents   | \`<source>/$BASE_SYNC_PATH/agents/\`   | \`<target>/agents/$UPSTREAM_FOLDER\`   |

Please make changes at the source location. Use the target location's agent rules to describe how to update them. Pay close attention to updating synced rules versus rules that describe working with the target repository.

Agent rules can be found at places like:

- \`**/AGENTS.md\`
- \`**/CLAUDE.md\`
- \`**/.claude/rules/\`
- \`.github/copilot-instructions.md\`
- \`.github/instructions/*.instructions.md\`
EOF
)

    if [[ "$DRY_RUN" == true ]]; then
        dryrun "Would create: $doc_file"
        dryrun "Contents:"
        # Show indented content preview
        while IFS= read -r line; do
            dryrun "  $line"
        done <<< "$content"
    else
        mkdir -p "$target_rules_dir"
        echo "$content" > "$doc_file"
        success "Created: $doc_file"
    fi
}

# Sync a directory by creating a single directory symlink
sync_directory() {
    local source_type="$1"  # rules, agents, or commands
    local source_dir="$ROOT_DIR/$BASE_SYNC_PATH/$source_type"
    local target_type_dir="$TARGET_DIR/$source_type"
    local target_link="$target_type_dir/$UPSTREAM_FOLDER"

    info "Syncing $source_type..."

    # Show existing content in target directory (also handles migration inline)
    info "Existing $source_type in target:"
    list_existing_content "$target_type_dir" "$source_type" "$ROOT_DIR/$BASE_SYNC_PATH"

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

# Main
main() {
    local source_path="$ROOT_DIR/$BASE_SYNC_PATH"

    info "Source: $source_path"
    info "Target: $TARGET_DIR"
    info "Upstream folder: $UPSTREAM_FOLDER"

    if [[ "$DRY_RUN" == true ]]; then
        dryrun "=== DRY RUN MODE ==="
    fi

    # Sync each type (creates directory symlinks, migration handled inline)
    sync_directory "rules"
    generate_rules_doc  # Create documentation file alongside rules symlink
    sync_directory "agents"
    sync_directory "commands"

    if [[ "$DRY_RUN" == true ]]; then
        info "Dry run complete. No changes were made."
        # Show command to apply changes
        local apply_cmd="$0"
        if [[ "$TARGET_LEVEL" == "user" ]]; then
            apply_cmd="$apply_cmd --user"
        elif [[ "$TARGET_DIR" != "$ROOT_DIR/.claude" ]]; then
            apply_cmd="$apply_cmd --target \"$TARGET_DIR\""
        fi
        apply_cmd="$apply_cmd --no-dry-run"
        info "To apply these changes, run:"
        info "  $apply_cmd"
    else
        success "Sync complete!"
    fi
}

main
