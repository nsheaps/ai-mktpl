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

preview-version-bump PLUGIN_PATH=invocation_directory():
    #!/usr/bin/env bash
    command -v commit-and-tag-version >/dev/null 2>&1 || { just setup ; }
    source {{root_dir}}/bin/lib/stdlib.sh
    cd {{PLUGIN_PATH}}
    PLUGIN_DIR="$(dirname "$(find_up '.claude-plugin')")"
    cd "$PLUGIN_DIR"
    # echo "Current version is $(just plugin-current-version {{invocation_directory()}})"
    echo "===[ DRY RUN ]==="
    commit-and-tag-version --dry-run

[arg('format', pattern='--pattern=(raw|md)|')]
preview-version-bumps format='--pattern=raw':
    #!/usr/bin/env bash
    # takes optional args:
    # --format=raw|md : output format for dry-run report (default: raw)
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
    case "{{format}}" in
        --pattern=md )
            echo "| Plugin | Current | Type | Next |"
            echo "|---|---|---|---|"
            ;;
    esac
    for plugin_dir in plugins/*; do
        if [ ! -d "$plugin_dir" ]; then
            continue
        fi
        PLUGIN_NAME=$(basename "$plugin_dir")
        CURRENT=$(just plugin-current-version "$plugin_dir")
        NEXT=$(just plugin-next-version "$plugin_dir")
        # determine type of bump
        IFS='.' read -r -a current_parts <<< "$CURRENT"
        IFS='.' read -r -a next_parts <<< "$NEXT"
        if [ "${current_parts[0]}" != "${next_parts[0]}" ]; then
            TYPE="major"
        elif [ "${current_parts[1]}" != "${next_parts[1]}" ]; then
            TYPE="minor"
        elif [ "${current_parts[2]}" != "${next_parts[2]}" ]; then
            TYPE="patch"
        else
            TYPE="none"
        fi

        case "{{format}}" in
            --pattern=raw|'' )
                echo "$PLUGIN_NAME: $CURRENT =( $TYPE )=> $NEXT"
                ;;
            --pattern=md )
                echo "| $PLUGIN_NAME | $CURRENT | $TYPE | $NEXT |"
                ;;
        esac
    done

plugin-current-versions:
    #!/usr/bin/env bash
    # returns a list of plugin names and their current versions
    for plugin_dir in plugins/*; do
        {
          if [ ! -d "$plugin_dir" ]; then
              continue
          fi
          PLUGIN_NAME=$(basename "$plugin_dir")
          CURRENT=$(just plugin-current-version "$plugin_dir")
          echo "$PLUGIN_NAME: $CURRENT"
        } &
    done
    wait

plugin-current-version PLUGIN_PATH=invocation_directory():
    #!/usr/bin/env bash
    # returns just the semver of the plugin at PLUGIN_PATH
    command -v commit-and-tag-version >/dev/null 2>&1 || { just setup ; }
    source {{root_dir}}/bin/lib/stdlib.sh
    cd {{PLUGIN_PATH}}
    PLUGIN_DIR="$(dirname "$(find_up '.claude-plugin')")"
    cd "$PLUGIN_DIR"
    echo "$(jq -r '.version' .claude-plugin/plugin.json)" | xargs

plugin-next-version PLUGIN_PATH=invocation_directory():
    #!/usr/bin/env bash
    # returns just the semver (aka 1.1.0)
    command -v commit-and-tag-version >/dev/null 2>&1 || { just setup ; }
    source {{root_dir}}/bin/lib/stdlib.sh
    cd {{PLUGIN_PATH}}
    PLUGIN_DIR="$(dirname "$(find_up '.claude-plugin')")"
    cd "$PLUGIN_DIR"
    commit-and-tag-version --dry-run --skip.changelog --skip.commit | grep -Eo 'to \d+\.\d+\.\d+' | sed 's/to //g'

bump-plugin-version PLUGIN_PATH=invocation_directory():
    #!/usr/bin/env bash
    command -v commit-and-tag-version >/dev/null 2>&1 || { just setup ; }
    source {{root_dir}}/bin/lib/stdlib.sh
    cd {{PLUGIN_PATH}}
    PLUGIN_DIR="$(dirname "$(find_up '.claude-plugin')")"
    cd "$PLUGIN_DIR"
    commit-and-tag-version

bump-plugin-versions:
    #!/usr/bin/env bash
    for plugin_dir in plugins/*; do
        if [ ! -d "$plugin_dir" ]; then
            continue
        fi
        just bump-plugin-version "$plugin_dir"
    done

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

