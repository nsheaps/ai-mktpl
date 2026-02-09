# Claude Code Plugin Marketplace - Local Development Commands
#
# Prerequisites:
#   - just: https://github.com/casey/just
#   - mise: https://mise.run
#   - jq: for JSON processing
#
# Usage:
#   just          # Show available commands
#   just lint     # Run all linters
#   just validate # Validate plugin structure
#   just check    # Run all checks (lint + validate)

set unstable

claude := which("claude") || 'mise exec npm:@anthropic-ai/claude-code -- claude'
# By default, just runs from the directory where the justfile is defined.
# https://just.systems/man/en/working-directory.html
root_dir := justfile_directory()

# Default recipe: show help
default:
    @just --list

# Install development dependencies via mise and yarn
setup:
    @echo "Pruning unused tools"
    mise prune -y
    @echo "Installing tools via mise..."
    mise install -y
    @echo "Installing yarn dependencies (release-it)..."
    yarn install
    @echo "Setup complete!"

# Run all linters (uses .prettierrc.yaml for config)
# Optional FILE argument to lint a single file
lint FILE='.':
    #!/usr/bin/env bash
    command -v prettier >/dev/null 2>&1 || { just setup ; }
    if just lint-check "{{FILE}}"; then
        exit 0
    fi
    echo "Lint errors found. Attempting to fix..."
    just lint-fix "{{FILE}}"
    # Exit based on whether issues remain - CI handles detecting/committing changes
    just lint-check "{{FILE}}"

lint-fix FILE='.':
    #!/usr/bin/env bash
    command -v prettier >/dev/null 2>&1 || { just setup ; }
    prettier --write --list-different "{{FILE}}"

lint-check FILE='.':
    #!/usr/bin/env bash
    command -v prettier >/dev/null 2>&1 || { just setup ; }
    prettier --check "{{FILE}}"

validate-marketplace:
    @just validate-plugin .claude-plugin/marketplace.json

validate-plugin PLUGIN_PATH:
    #!/usr/bin/env bash
    OUTPUT="$({{claude}} plugin validate {{PLUGIN_PATH}})"
    if [ $? -ne 0 ]; then
        echo "$OUTPUT"
        exit 1
    else
        echo "✅ {{PLUGIN_PATH}}"
    fi

# Validate plugin structure
validate:
    #!/usr/bin/env bash
    set -e
    just validate-marketplace

    VALID=true
    FAILED_PLUGINS=( )
    for plugin_dir in plugins/*/.claude-plugin/plugin.json; do
        just validate-plugin "$plugin_dir" || { VALID=false; FAILED_PLUGINS+=($plugin_dir) ; }
    done

    # if the path to the claude binary is in */.local/share/mise/installs/* then mise prune in case it was installed at runtime
    if [[ "$(command -v claude)" == *".local/share/mise/installs/"* ]]; then
        echo "Pruning mise installs..."
        mise prune -y
    fi

    if [ "$VALID" = true ]; then
        echo "All plugins validated successfully!"
    else
        echo "Validation failed!"
        echo "Failed plugins:"
        for p in "${FAILED_PLUGINS[@]}"; do
            echo " - $p"
        done
        exit 1
    fi

# Preview version bump for a single plugin (dry-run)
_preview-version-bump PLUGIN_PATH=invocation_directory():
    #!/usr/bin/env bash
    [ -f "{{root_dir}}/.pnp.cjs" ] || { just setup ; }
    source {{root_dir}}/bin/lib/stdlib.sh
    cd {{PLUGIN_PATH}}
    PLUGIN_DIR="$(dirname "$(find_up '.claude-plugin')")"
    cd "$PLUGIN_DIR"
    echo "===[ DRY RUN for $(basename $PLUGIN_DIR) ]==="
    yarn exec release-it --dry-run --ci 2>&1 || echo "No release needed"

# Compare plugin versions between base branch (main) and current HEAD
# Shows actual version changes in PR, not predicted future bumps
[arg('format', pattern='--format=raw|--format=md')]
_preview-version-bumps format='--format=raw':
    #!/usr/bin/env bash
    # Determine base branch (origin/main in CI, main locally)
    BASE_BRANCH="${GITHUB_BASE_REF:-main}"
    if ! git rev-parse --verify "origin/$BASE_BRANCH" >/dev/null 2>&1; then
        BASE_BRANCH="main"
    else
        BASE_BRANCH="origin/$BASE_BRANCH"
    fi

    case "{{format}}" in
        --format=md )
            echo "| Plugin | Base | Type | Head |"
            echo "|---|---|---|---|"
            ;;
    esac

    FOUND_CHANGES=0
    for plugin_dir in plugins/*; do
        if [ ! -d "$plugin_dir" ]; then
            continue
        fi
        PLUGIN_NAME=$(basename "$plugin_dir")
        PLUGIN_JSON="$plugin_dir/.claude-plugin/plugin.json"

        # Get version from HEAD (current branch)
        HEAD_VERSION=$(jq -r '.version' "$PLUGIN_JSON" 2>/dev/null || echo "")
        if [ -z "$HEAD_VERSION" ]; then
            continue
        fi

        # Get version from base branch
        BASE_VERSION=$(git show "$BASE_BRANCH:$PLUGIN_JSON" 2>/dev/null | jq -r '.version' 2>/dev/null || echo "")
        if [ -z "$BASE_VERSION" ]; then
            # Plugin doesn't exist in base branch (new plugin)
            BASE_VERSION="0.0.0"
        fi

        # Skip if versions are the same
        if [ "$BASE_VERSION" = "$HEAD_VERSION" ]; then
            continue
        fi

        # Determine type of bump
        IFS='.' read -r -a base_parts <<< "$BASE_VERSION"
        IFS='.' read -r -a head_parts <<< "$HEAD_VERSION"
        if [ "${base_parts[0]}" != "${head_parts[0]}" ]; then
            TYPE="major"
        elif [ "${base_parts[1]}" != "${head_parts[1]}" ]; then
            TYPE="minor"
        elif [ "${base_parts[2]}" != "${head_parts[2]}" ]; then
            TYPE="patch"
        else
            TYPE="unknown"
        fi

        FOUND_CHANGES=1
        case "{{format}}" in
            --format=raw|'' )
                echo "$PLUGIN_NAME: $BASE_VERSION =( $TYPE )=> $HEAD_VERSION"
                ;;
            --format=md )
                echo "| $PLUGIN_NAME | $BASE_VERSION | $TYPE | $HEAD_VERSION |"
                ;;
        esac
    done

    if [ "$FOUND_CHANGES" -eq 0 ]; then
        case "{{format}}" in
            --format=md )
                echo "| *No version changes detected* | | | |"
                ;;
            * )
                echo "No version changes detected"
                ;;
        esac
    fi

# Detect plugins with code changes and output JSON for CI/CD
# Usage: just detect-plugin-changes [base-ref]
# Output: JSON with has_changes, plugins array, and report_md
detect-plugin-changes base_ref='main':
    #!/usr/bin/env bash
    set -euo pipefail

    BASE_REF="{{base_ref}}"

    # Resolve base ref - prefer origin/ref if it exists
    if git rev-parse --verify "origin/$BASE_REF" >/dev/null 2>&1; then
        BASE_REF="origin/$BASE_REF"
    elif ! git rev-parse --verify "$BASE_REF" >/dev/null 2>&1; then
        # Fallback to HEAD~1 if base ref doesn't exist
        BASE_REF="HEAD~1"
    fi

    # Build JSON output
    PLUGINS_JSON="[]"
    REPORT_MD="| Plugin | Current | → | After Merge |\n|---|---|---|---|"

    for plugin_dir in plugins/*; do
        if [ ! -d "$plugin_dir" ]; then
            continue
        fi

        PLUGIN_NAME=$(basename "$plugin_dir")
        PLUGIN_JSON="$plugin_dir/.claude-plugin/plugin.json"

        # Check if plugin has code changes (excluding plugin.json and CHANGELOG.md)
        if ! git diff --name-only "$BASE_REF..HEAD" -- "$plugin_dir" 2>/dev/null | grep -v 'CHANGELOG.md$' | grep -v 'plugin.json$' | grep -q .; then
            continue
        fi

        # Get current version
        CURRENT_VERSION=$(jq -r '.version' "$PLUGIN_JSON" 2>/dev/null || echo "0.0.0")

        # Calculate next patch version
        IFS='.' read -r major minor patch <<< "$CURRENT_VERSION"
        NEXT_VERSION="$major.$minor.$((patch + 1))"

        # Add to plugins JSON array
        PLUGINS_JSON=$(echo "$PLUGINS_JSON" | jq -c ". + [{\"name\": \"$PLUGIN_NAME\", \"current\": \"$CURRENT_VERSION\", \"next\": \"$NEXT_VERSION\"}]")

        # Add to markdown report
        REPORT_MD="$REPORT_MD\n| $PLUGIN_NAME | $CURRENT_VERSION | → | $NEXT_VERSION |"
    done

    # Determine if there are changes
    PLUGIN_COUNT=$(echo "$PLUGINS_JSON" | jq 'length')
    if [ "$PLUGIN_COUNT" -gt 0 ]; then
        HAS_CHANGES="true"
        PLUGINS_LIST=$(echo "$PLUGINS_JSON" | jq -r '.[].name' | tr '\n' ' ' | xargs)
    else
        HAS_CHANGES="false"
        PLUGINS_LIST=""
        REPORT_MD="| Plugin | Current | → | After Merge |\n|---|---|---|---|\n| *No changes detected* | | | |"
    fi

    # Output final JSON
    jq -n \
        --argjson has_changes "$HAS_CHANGES" \
        --arg plugins "$PLUGINS_LIST" \
        --argjson plugins_json "$PLUGINS_JSON" \
        --arg report_md "$(printf '%b' "$REPORT_MD")" \
        '{
            has_changes: $has_changes,
            plugins: $plugins,
            plugins_json: $plugins_json,
            report_md: $report_md
        }'

_plugin-current-versions:
    #!/usr/bin/env bash
    # returns a list of plugin names and their current versions
    for plugin_dir in plugins/*; do
        {
          if [ ! -d "$plugin_dir" ]; then
              continue
          fi
          PLUGIN_NAME=$(basename "$plugin_dir")
          CURRENT=$(just _plugin-current-version "$plugin_dir")
          echo "$PLUGIN_NAME: $CURRENT"
        } &
    done
    wait

_plugin-current-version PLUGIN_PATH=invocation_directory():
    #!/usr/bin/env bash
    # returns just the semver of the plugin at PLUGIN_PATH
    source {{root_dir}}/bin/lib/stdlib.sh
    cd {{PLUGIN_PATH}}
    PLUGIN_DIR="$(dirname "$(find_up '.claude-plugin')")"
    cd "$PLUGIN_DIR"
    echo "$(jq -r '.version' .claude-plugin/plugin.json)" | xargs

# Bump plugin version using release-it
# Reads current version from plugin.json, applies patch bump
_bump-plugin-version PLUGIN_PATH=invocation_directory():
    #!/usr/bin/env bash
    [ -f "{{root_dir}}/.pnp.cjs" ] || { just setup ; }
    source {{root_dir}}/bin/lib/stdlib.sh
    cd {{PLUGIN_PATH}}
    PLUGIN_DIR="$(dirname "$(find_up '.claude-plugin')")"
    cd "$PLUGIN_DIR"
    PLUGIN_NAME=$(basename "$PLUGIN_DIR")

    echo "=== Bumping version for $PLUGIN_NAME ==="
    yarn exec release-it --ci

# Bump all plugin versions (only those with changes)
_bump-plugin-versions:
    #!/usr/bin/env bash
    for plugin_dir in plugins/*; do
        if [ ! -d "$plugin_dir" ]; then
            continue
        fi
        just _bump-plugin-version "$plugin_dir"
    done

# Bump versions for changed plugins only
# BASE_REF is used to detect which plugins have changes
_bump-changed-plugins BASE_REF='origin/main':
    #!/usr/bin/env bash
    [ -f "{{root_dir}}/.pnp.cjs" ] || { just setup ; }

    for plugin_dir in plugins/*; do
        if [ ! -d "$plugin_dir" ]; then
            continue
        fi
        PLUGIN_NAME=$(basename "$plugin_dir")

        # Check if plugin has changes (excluding CHANGELOG.md and plugin.json)
        if git diff --name-only "{{BASE_REF}}..HEAD" -- "$plugin_dir" | grep -v 'CHANGELOG.md$' | grep -v 'plugin.json$' | grep -q .; then
            echo "=== Bumping version for $PLUGIN_NAME (has changes) ==="
            cd "$plugin_dir"
            yarn exec release-it --ci
            cd - > /dev/null
        else
            echo "=== Skipping $PLUGIN_NAME (no changes) ==="
        fi
    done

# Bump plugin versions (use --dry-run to preview)
release *FLAGS:
    #!/usr/bin/env bash
    if [[ "{{FLAGS}}" == *"--dry-run"* ]]; then
        # Extract format flag if present, default to raw
        if [[ "{{FLAGS}}" == *"--format=md"* ]]; then
            just _preview-version-bumps --format=md
        else
            just _preview-version-bumps --format=raw
        fi
    else
        just _bump-plugin-versions
    fi

# Update marketplace.json from plugin.json files
update-marketplace:
    #!/usr/bin/env bash
    set -e
    echo "Updating marketplace.json..."

    MARKETPLACE_FILE=".claude-plugin/marketplace.json"
    TEMP_FILE=$(mktemp)
    UPDATED=false
    CHANGED_PLUGINS=""

    # Start with empty plugins array
    jq '.plugins = []' "$MARKETPLACE_FILE" > "$TEMP_FILE"

    for plugin_dir in plugins/*; do
        if [ ! -d "$plugin_dir" ]; then
            continue
        fi

        PLUGIN_NAME=$(basename "$plugin_dir")
        PLUGIN_JSON="$plugin_dir/.claude-plugin/plugin.json"

        if [ ! -f "$PLUGIN_JSON" ]; then
            echo "Skipping $PLUGIN_NAME (no plugin.json)"
            continue
        fi

        VERSION=$(jq -r '.version' "$PLUGIN_JSON")
        DESC=$(jq -r '.description' "$PLUGIN_JSON")
        AUTHOR=$(jq -r '.author.name' "$PLUGIN_JSON")
        KEYWORDS=$(jq -c '.keywords // []' "$PLUGIN_JSON")

        # Check if version changed from current marketplace
        CURRENT_VERSION=$(jq -r ".plugins[] | select(.name == \"$PLUGIN_NAME\") | .version" "$MARKETPLACE_FILE" 2>/dev/null || echo "")
        if [ "$VERSION" != "$CURRENT_VERSION" ] && [ -n "$CURRENT_VERSION" ]; then
            echo "Version changed: $PLUGIN_NAME $CURRENT_VERSION -> $VERSION"
            CHANGED_PLUGINS="${CHANGED_PLUGINS}${PLUGIN_NAME},"
        fi

        # Determine category
        CATEGORY="utility"
        if echo "$PLUGIN_NAME" | grep -q "git\|commit"; then
            CATEGORY="git"
        fi

        # Determine tags
        TAGS='["utility"]'
        if [ -d "$plugin_dir/commands" ]; then
            TAGS=$(echo "$TAGS" | jq '. += ["command"]')
        fi
        if [ -d "$plugin_dir/skills" ]; then
            TAGS=$(echo "$TAGS" | jq '. += ["skill"]')
        fi

        jq --arg name "$PLUGIN_NAME" \
           --arg version "$VERSION" \
           --arg desc "$DESC" \
           --arg author "$AUTHOR" \
           --arg source "./plugins/$PLUGIN_NAME" \
           --arg category "$CATEGORY" \
           --argjson tags "$TAGS" \
           --argjson keywords "$KEYWORDS" \
           '.plugins += [{
             name: $name,
             description: $desc,
             version: $version,
             author: {name: $author},
             source: $source,
             category: $category,
             tags: $tags,
             keywords: $keywords
           }]' "$TEMP_FILE" > "${TEMP_FILE}.new"

        mv "${TEMP_FILE}.new" "$TEMP_FILE"
        echo "Added $PLUGIN_NAME"
    done

    # Sort the new marketplace
    jq '.plugins |= sort_by(.name)' "$TEMP_FILE" > "${TEMP_FILE}.sorted"

    # Compare with current marketplace to detect changes
    if ! diff -q "$MARKETPLACE_FILE" "${TEMP_FILE}.sorted" > /dev/null 2>&1; then
        UPDATED=true
        mv "${TEMP_FILE}.sorted" "$MARKETPLACE_FILE"
        echo "Marketplace updated!"
    else
        echo "No changes to marketplace"
    fi

    rm -f "$TEMP_FILE" "${TEMP_FILE}.sorted"

    # Remove trailing comma from changed plugins
    CHANGED_PLUGINS=$(echo "$CHANGED_PLUGINS" | sed 's/,$//')

    # Output for GitHub Actions if running in CI
    if [ -n "$GITHUB_OUTPUT" ]; then
        echo "updated=${UPDATED}" >> "$GITHUB_OUTPUT"
        echo "changed-plugins=${CHANGED_PLUGINS}" >> "$GITHUB_OUTPUT"
    fi

    echo "Updated: $UPDATED"
    if [ -n "$CHANGED_PLUGINS" ]; then
        echo "Changed plugins: $CHANGED_PLUGINS"
    fi

    just lint-fix

# Run all checks (lint + validate)
check:
    @just lint
    @just validate

# Test plugin configuration doesn't cause git changes
test-plugin-config PLUGIN:
    #!/usr/bin/env bash
    SCRIPT="./plugins/{{PLUGIN}}/scripts/test-configuration.sh"
    if [[ ! -f "$SCRIPT" ]]; then
        echo "No test script found for {{PLUGIN}}"
        exit 0
    fi
    "$SCRIPT"

# Test all plugins with configuration tests
test-all-plugin-configs:
    #!/usr/bin/env bash
    for script in plugins/*/scripts/test-configuration.sh; do
        if [[ -f "$script" ]]; then
            plugin_dir=$(dirname "$(dirname "$script")")
            plugin_name=$(basename "$plugin_dir")
            echo "Testing $plugin_name..."
            "$script" || exit 1
        fi
    done
    echo "All plugin configuration tests passed!"

