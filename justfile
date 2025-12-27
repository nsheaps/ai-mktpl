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

# Default recipe: show help
default:
    @just --list

# Install development dependencies via mise
setup:
    @echo "Pruning unused tools"
    mise prune -y
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

claude := which("claude") || 'mise exec npm:@anthropic-ai/claude-code -- claude'

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


preview-version-bump PLUGIN_NAME:
    # returns the next version for the given plugin name (path assumed) using SVU
    @echo "unimplemented"

plugin-current-version PLUGIN_NAME:
    # returns the current version for the given plugin name (path assumed)
    @echo "unimplemented"

[arg('format', pattern='--pattern=(raw|md|json)|')]
preview-version-bumps format='--pattern=raw':
    # takes optional args:
    # --format=raw|md|json : output format for dry-run report (default: raw)
    # gets the json, then formats it accordingly.
    # format with raw:
    #  plugin-name: 1.2.2 =( patch )=> 1.2.3
    #  $plugin: $current =( $type )=> $next
    #  ...
    # format with md:
    #  | Plugin | Current | Type | Next | 
    #  |---|---|---|---|
    #  | plugin-name | 1.2.2 | patch | 1.2.3 |
    #   ...
    # format with json:
    #  [
    #    {
    #      "name": "plugin-name",
    #      "current": "1.2.2",
    #      "type": "patch",
    #      "next": "1.2.3"
    #    },
    #    ...
    #  ]
    @echo "FORMAT: {{format}}"
    @echo "unimplemented"

bump-plugin-version PLUGIN_PATH:
    @echo "unimplemented"

bump-plugin-versions:
    # goes through each plugin and attempts to bump it
    @echo "unimplemented"

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

