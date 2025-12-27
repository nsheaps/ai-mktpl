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

# Default recipe: show help
default:
    @just --list

# Install development dependencies via mise
setup:
    @echo "Installing tools via mise..."
    mise install -y
    @echo "Setup complete!"

# Run all linters (uses .prettierrc.yaml for config)
lint:
    #!/usr/bin/env bash
    command -v prettier >/dev/null 2>&1 || { just setup ; }
    HAS_ERRORS=0
    just lint-check || HAS_ERRORS=1
    if [ $HAS_ERRORS -ne 0 ]; then
        echo "Lint errors found. Attempting to fix them"
        prettier --write --list-different .
        just lint-check || echo "Errors remain after auto-fix."
        echo "Lint failed earlier, exiting with error"
        exit 1
    fi


lint-check:
    command -v prettier >/dev/null 2>&1 || { just setup ; }
    prettier --check .

validate-marketplace:
    #!/usr/bin/env bash
    # Check marketplace.json exists and is valid JSON
    if [ ! -f ".claude-plugin/marketplace.json" ]; then
        echo "ERROR: marketplace.json not found"
        exit 1
    fi

    # start at root of repo
    claude plugin validate .

validate-plugin PLUGIN_PATH:
    claude plugin validate {{PLUGIN_PATH}}


# Validate plugin structure
validate:
    #!/usr/bin/env bash
    set -e
    # Use Claude CLI validator if available (validates JSON schema + structure)
    if ! command -v claude >/dev/null 2>&1; then
        echo "::warning::Claude CLI not found, skipping validation"
        exit 1
    fi
    just validate-marketplace

    VALID=true
    FAILED_PLUGINS=( )
    for plugin_dir in plugins/*/.claude-plugin/plugin.json; do
        just validate-plugin "$plugin_dir" || { VALID=false; FAILED_PLUGINS+=($plugin_dir) ; }
    done

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

# Update marketplace.json from plugin.json files
update-marketplace:
    #!/usr/bin/env bash
    set -e
    echo "Updating marketplace.json..."

    MARKETPLACE_FILE=".claude-plugin/marketplace.json"
    TEMP_FILE=$(mktemp)

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

    # Sort and save
    jq '.plugins |= sort_by(.name)' "$TEMP_FILE" > "$MARKETPLACE_FILE"
    rm -f "$TEMP_FILE"

    echo "Marketplace updated!"

# Run all checks (lint + validate)
check:
    @just lint
    @just validate

