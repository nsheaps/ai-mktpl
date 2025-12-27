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

# Run all linters
lint:
    command -v prettier >/dev/null 2>&1 || { just setup ; }
    # TODO convert to use prettier config file
    prettier --write "**/*.{yaml,yml,json,md}" --list-different

lint-check:
    command -v prettier >/dev/null 2>&1 || { just setup ; }
    prettier --check "**/*.{yaml,yml,json,md}"

# Validate plugin structure
validate:
    #!/usr/bin/env bash
    set -e
    echo "Validating plugin structure..."

    VALID=true
    # TODO does claude cli provide some validator? What about json schema validation?
    # Check marketplace.json exists and is valid
    if [ ! -f ".claude-plugin/marketplace.json" ]; then
        echo "ERROR: marketplace.json not found"
        exit 1
    fi

    if ! jq empty .claude-plugin/marketplace.json 2>/dev/null; then
        echo "ERROR: Invalid JSON in marketplace.json"
        exit 1
    fi

    echo "marketplace.json is valid"

    # Validate each plugin
    for plugin_dir in plugins/*; do
        if [ ! -d "$plugin_dir" ]; then
            continue
        fi

        PLUGIN_NAME=$(basename "$plugin_dir")
        PLUGIN_JSON="$plugin_dir/.claude-plugin/plugin.json"

        if [ ! -f "$PLUGIN_JSON" ]; then
            echo "WARNING: Plugin $PLUGIN_NAME missing plugin.json"
            continue
        fi

        if ! jq empty "$PLUGIN_JSON" 2>/dev/null; then
            echo "ERROR: Invalid JSON in $PLUGIN_JSON"
            VALID=false
            continue
        fi

        # Check required fields
        NAME=$(jq -r '.name' "$PLUGIN_JSON")
        VERSION=$(jq -r '.version' "$PLUGIN_JSON")
        DESC=$(jq -r '.description' "$PLUGIN_JSON")

        if [ -z "$NAME" ] || [ "$NAME" = "null" ]; then
            echo "ERROR: Plugin $PLUGIN_NAME missing 'name' field"
            VALID=false
        fi

        if [ -z "$VERSION" ] || [ "$VERSION" = "null" ]; then
            echo "ERROR: Plugin $PLUGIN_NAME missing 'version' field"
            VALID=false
        fi

        if [ -z "$DESC" ] || [ "$DESC" = "null" ]; then
            echo "ERROR: Plugin $PLUGIN_NAME missing 'description' field"
            VALID=false
        fi

        # Check semver format
        if ! echo "$VERSION" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+'; then
            echo "ERROR: Plugin $PLUGIN_NAME has invalid version format: $VERSION"
            VALID=false
        else
            echo "Plugin $PLUGIN_NAME validated (v$VERSION)"
        fi
    done

    if [ "$VALID" = "true" ]; then
        echo "All plugins validated successfully!"
    else
        echo "Validation failed!"
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

# Show plugin summary
plugins:
    @echo "Plugins in marketplace:"
    @jq -r '.plugins[] | "  - \(.name) v\(.version): \(.description)"' .claude-plugin/marketplace.json

# Clean generated files
clean:
    rm -rf node_modules
