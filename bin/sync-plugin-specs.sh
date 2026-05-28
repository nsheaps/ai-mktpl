#!/usr/bin/env bash
# sync-plugin-specs.sh — Sync SPEC.md files with the plugin filesystem
#
# For each plugin directory, ensures SPEC.md is in sync with actual filesystem items:
#   - If SPEC.md missing: auto-generate from plugin metadata + filesystem scan
#   - If filesystem item not in spec: append entry to relevant SPEC.md section
#   - If spec item not in filesystem: create placeholder file/dir
#   - Both exist: leave alone
#
# Usage: sync-plugin-specs.sh [plugins-dir]
#   plugins-dir defaults to $(dirname "$0")/../plugins

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGINS_DIR="${1:-${SCRIPT_DIR}/../plugins}"
PLUGINS_DIR="$(cd "$PLUGINS_DIR" && pwd)"

CHANGES=()

log_change() {
    local msg="$1"
    echo "$msg"
    CHANGES+=("$msg")
}

# Extract the first substantive description line from a markdown file
# Skips: # headings, blank lines, leading "- " or "> " markers
# Returns up to 80 chars (with ... if truncated)
extract_description() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        echo "_description needed_"
        return
    fi
    local desc=""
    while IFS= read -r line; do
        # Skip empty lines
        [[ -z "$line" ]] && continue
        # Skip heading lines (# or ##, etc.)
        [[ "$line" =~ ^#+ ]] && continue
        # Skip YAML frontmatter markers
        [[ "$line" == "---" ]] && continue
        # Strip leading "- " or "> "
        line="${line#- }"
        line="${line#> }"
        # Skip if still empty after stripping
        [[ -z "$line" ]] && continue
        desc="$line"
        break
    done < "$file"

    if [[ -z "$desc" ]]; then
        echo "_description needed_"
        return
    fi

    # Check YAML frontmatter for description field
    local yaml_desc
    yaml_desc=$(awk '/^---/{p=!p;next} p && /^description:/{sub(/^description:[[:space:]]*/,""); print; exit}' "$file" 2>/dev/null || true)
    if [[ -n "$yaml_desc" ]]; then
        desc="$yaml_desc"
        # Remove surrounding quotes if present
        desc="${desc#\"}"
        desc="${desc%\"}"
        desc="${desc#\'}"
        desc="${desc%\'}"
    fi

    # Truncate at 80 chars
    if [[ ${#desc} -gt 80 ]]; then
        desc="${desc:0:80}..."
    fi
    echo "$desc"
}

# Get plugin name from plugin.json, falling back to directory name
get_plugin_name() {
    local plugin_dir="$1"
    local plugin_json="${plugin_dir}/.claude-plugin/plugin.json"
    if [[ -f "$plugin_json" ]]; then
        jq -r '.name // empty' "$plugin_json" 2>/dev/null || basename "$plugin_dir"
    else
        basename "$plugin_dir"
    fi
}

# Get plugin description from plugin.json, falling back to placeholder
get_plugin_description() {
    local plugin_dir="$1"
    local plugin_json="${plugin_dir}/.claude-plugin/plugin.json"
    if [[ -f "$plugin_json" ]]; then
        local desc
        desc=$(jq -r '.description // empty' "$plugin_json" 2>/dev/null || true)
        if [[ -n "$desc" ]]; then
            echo "$desc"
            return
        fi
    fi
    # Try README.md first line
    if [[ -f "${plugin_dir}/README.md" ]]; then
        local readme_desc
        readme_desc=$(grep -m1 '^[^#]' "${plugin_dir}/README.md" 2>/dev/null || true)
        if [[ -n "$readme_desc" ]]; then
            echo "$readme_desc"
            return
        fi
    fi
    echo "_description needed_"
}

# Scan filesystem for actual skills (dirs in skills/ that have SKILL.md)
scan_skills() {
    local plugin_dir="$1"
    local skills_dir="${plugin_dir}/skills"
    if [[ ! -d "$skills_dir" ]]; then
        return
    fi
    for skill_dir in "$skills_dir"/*/; do
        [[ -d "$skill_dir" ]] || continue
        local skill_name
        skill_name=$(basename "$skill_dir")
        if [[ -f "${skill_dir}/SKILL.md" ]]; then
            echo "$skill_name"
        fi
    done
}

# Scan filesystem for actual rules (.md files in rules/)
scan_rules() {
    local plugin_dir="$1"
    local rules_dir="${plugin_dir}/rules"
    if [[ ! -d "$rules_dir" ]]; then
        return
    fi
    for rule_file in "$rules_dir"/*.md; do
        [[ -f "$rule_file" ]] || continue
        local rule_name
        rule_name=$(basename "$rule_file" .md)
        echo "$rule_name"
    done
}

# Scan filesystem for actual commands (.md files in commands/)
scan_commands() {
    local plugin_dir="$1"
    local commands_dir="${plugin_dir}/commands"
    if [[ ! -d "$commands_dir" ]]; then
        return
    fi
    for cmd_file in "$commands_dir"/*.md; do
        [[ -f "$cmd_file" ]] || continue
        local cmd_name
        cmd_name=$(basename "$cmd_file" .md)
        echo "$cmd_name"
    done
}

# Parse hooks from hooks/hooks.json
# Returns lines: "type|script_type|description"
scan_hooks() {
    local plugin_dir="$1"
    local hooks_json="${plugin_dir}/hooks/hooks.json"

    if [[ -f "$hooks_json" ]]; then
        local description
        description=$(jq -r '.description // "_description needed_"' "$hooks_json" 2>/dev/null || echo "_description needed_")

        # Get all hook types from the hooks object keys
        local hook_types
        hook_types=$(jq -r '.hooks | keys[]' "$hooks_json" 2>/dev/null || true)

        while IFS= read -r hook_type; do
            [[ -z "$hook_type" ]] && continue
            # Determine script type from the hook entries for this type
            local script_type
            script_type=$(jq -r --arg t "$hook_type" '.hooks[$t][].hooks[].type // empty' "$hooks_json" 2>/dev/null | sort -u | head -1 || true)
            [[ -z "$script_type" ]] && script_type="bash"
            echo "${hook_type}|${script_type}|${description}"
        done <<< "$hook_types"
        return
    fi

    # Fallback: check for hooks/scripts/*.sh
    local scripts_dir="${plugin_dir}/hooks/scripts"
    if [[ -d "$scripts_dir" ]]; then
        for sh_file in "$scripts_dir"/*.sh; do
            [[ -f "$sh_file" ]] || continue
            local script_name
            script_name=$(basename "$sh_file" .sh)
            echo "unknown|bash|${script_name}"
        done
    fi
}

# Parse items from a SPEC.md section
# Usage: parse_spec_section <spec_file> <section_heading>
# Outputs one item name per line
parse_spec_section() {
    local spec_file="$1"
    local section="$2"
    if [[ ! -f "$spec_file" ]]; then
        return
    fi
    local in_section=0
    while IFS= read -r line; do
        if [[ "$line" =~ ^##[[:space:]]+${section}$ ]]; then
            in_section=1
            continue
        fi
        # Stop at next ## heading
        if [[ $in_section -eq 1 ]] && [[ "$line" =~ ^## ]]; then
            break
        fi
        if [[ $in_section -eq 1 ]]; then
            # Match lines like: - `name` — description
            if [[ "$line" =~ ^\-[[:space:]]+\`([^\`]+)\` ]]; then
                echo "${BASH_REMATCH[1]}"
            fi
        fi
    done < "$spec_file"
}

# Check if a section exists in SPEC.md
spec_has_section() {
    local spec_file="$1"
    local section="$2"
    grep -q "^## ${section}$" "$spec_file" 2>/dev/null
}

# Append a new section to SPEC.md if it doesn't exist
ensure_spec_section() {
    local spec_file="$1"
    local section="$2"
    if ! spec_has_section "$spec_file" "$section"; then
        printf '\n## %s\n' "$section" >> "$spec_file"
    fi
}

# Append an item to a specific section in SPEC.md
append_to_section() {
    local spec_file="$1"
    local section="$2"
    local item_line="$3"

    # Create a temp file with the new content inserted after the section heading
    local tmp
    tmp=$(mktemp)
    local in_section=0
    local inserted=0
    while IFS= read -r line; do
        echo "$line" >> "$tmp"
        if [[ "$line" =~ ^##[[:space:]]+${section}$ ]]; then
            in_section=1
            continue
        fi
        if [[ $in_section -eq 1 ]] && [[ $inserted -eq 0 ]]; then
            if [[ "$line" =~ ^## ]] || [[ -z "$line" && $(grep -c "^## " "$spec_file") -eq 1 ]]; then
                # We've reached the end of the section or next section without inserting
                # We need a different approach - append at end of section
                :
            fi
        fi
    done < "$spec_file"
    rm -f "$tmp"

    # Simpler approach: use awk to insert after last item in section
    local tmp2
    tmp2=$(mktemp)
    awk -v section="$section" -v newline="$item_line" '
        BEGIN { in_section=0; found_section=0 }
        /^## / {
            if (in_section && !found_section) {
                # We were in the section and hit a new section - insert before this line
                print newline
                found_section=1
            }
            in_section = ($0 == "## " section)
        }
        { print }
        END {
            if (in_section && !found_section) {
                # Section was at end of file
                print newline
            }
        }
    ' "$spec_file" > "$tmp2"
    mv "$tmp2" "$spec_file"
}

# Generate a new SPEC.md for a plugin
generate_spec() {
    local plugin_dir="$1"
    local spec_file="${plugin_dir}/SPEC.md"
    local plugin_name
    plugin_name=$(get_plugin_name "$plugin_dir")
    local plugin_desc
    plugin_desc=$(get_plugin_description "$plugin_dir")

    {
        echo "# Plugin: ${plugin_name}"
        echo ""
        echo "**Purpose**: ${plugin_desc}"
        echo ""

        # Skills section
        local skills
        skills=$(scan_skills "$plugin_dir")
        if [[ -n "$skills" ]]; then
            echo "## Skills"
            echo ""
            while IFS= read -r skill_name; do
                [[ -z "$skill_name" ]] && continue
                local skill_desc
                skill_desc=$(extract_description "${plugin_dir}/skills/${skill_name}/SKILL.md")
                echo "- \`${skill_name}\` — ${skill_desc}"
            done <<< "$skills"
            echo ""
        fi

        # Rules section
        local rules
        rules=$(scan_rules "$plugin_dir")
        if [[ -n "$rules" ]]; then
            echo "## Rules"
            echo ""
            while IFS= read -r rule_name; do
                [[ -z "$rule_name" ]] && continue
                local rule_desc
                rule_desc=$(extract_description "${plugin_dir}/rules/${rule_name}.md")
                echo "- \`${rule_name}\` — ${rule_desc}"
            done <<< "$rules"
            echo ""
        fi

        # Hooks section
        local hooks_output
        hooks_output=$(scan_hooks "$plugin_dir")
        if [[ -n "$hooks_output" ]]; then
            echo "## Hooks"
            echo ""
            while IFS= read -r hook_line; do
                [[ -z "$hook_line" ]] && continue
                IFS='|' read -r hook_type script_type hook_desc <<< "$hook_line"
                echo "- \`${hook_type}\` (\`${script_type}\`) — ${hook_desc}"
            done <<< "$hooks_output"
            echo ""
        fi

        # Commands section
        local commands
        commands=$(scan_commands "$plugin_dir")
        if [[ -n "$commands" ]]; then
            echo "## Commands"
            echo ""
            while IFS= read -r cmd_name; do
                [[ -z "$cmd_name" ]] && continue
                local cmd_desc
                cmd_desc=$(extract_description "${plugin_dir}/commands/${cmd_name}.md")
                echo "- \`${cmd_name}\` — ${cmd_desc}"
            done <<< "$commands"
            echo ""
        fi
    } > "$spec_file"
}

# Process a single plugin directory
process_plugin() {
    local plugin_dir="$1"
    local plugin_name
    plugin_name=$(basename "$plugin_dir")
    local spec_file="${plugin_dir}/SPEC.md"
    local rel_path="plugins/${plugin_name}"

    # Generate SPEC.md if missing
    if [[ ! -f "$spec_file" ]]; then
        generate_spec "$plugin_dir"
        log_change "${rel_path}/SPEC.md: generated (new)"
        return
    fi

    # --- Sync Skills ---
    local fs_skills=()
    while IFS= read -r s; do
        [[ -n "$s" ]] && fs_skills+=("$s")
    done < <(scan_skills "$plugin_dir")

    local spec_skills=()
    while IFS= read -r s; do
        [[ -n "$s" ]] && spec_skills+=("$s")
    done < <(parse_spec_section "$spec_file" "Skills")

    # Filesystem skill not in spec → append to spec
    for skill_name in "${fs_skills[@]+"${fs_skills[@]}"}"; do
        local found=0
        for s in "${spec_skills[@]+"${spec_skills[@]}"}"; do
            [[ "$s" == "$skill_name" ]] && found=1 && break
        done
        if [[ $found -eq 0 ]]; then
            local skill_desc
            skill_desc=$(extract_description "${plugin_dir}/skills/${skill_name}/SKILL.md")
            ensure_spec_section "$spec_file" "Skills"
            append_to_section "$spec_file" "Skills" "- \`${skill_name}\` — ${skill_desc}"
            log_change "${rel_path}/SPEC.md: added skill '${skill_name}'"
        fi
    done

    # Spec skill not in filesystem → create placeholder
    for skill_name in "${spec_skills[@]+"${spec_skills[@]}"}"; do
        local found=0
        for s in "${fs_skills[@]+"${fs_skills[@]}"}"; do
            [[ "$s" == "$skill_name" ]] && found=1 && break
        done
        if [[ $found -eq 0 ]]; then
            local skill_dir="${plugin_dir}/skills/${skill_name}"
            mkdir -p "$skill_dir"
            local skill_file="${skill_dir}/SKILL.md"
            if [[ ! -f "$skill_file" ]]; then
                printf '# %s\n\n_description needed_\n' "$skill_name" > "$skill_file"
                log_change "${rel_path}/skills/${skill_name}/SKILL.md: created (from spec)"
            fi
        fi
    done

    # --- Sync Rules ---
    local fs_rules=()
    while IFS= read -r r; do
        [[ -n "$r" ]] && fs_rules+=("$r")
    done < <(scan_rules "$plugin_dir")

    local spec_rules=()
    while IFS= read -r r; do
        [[ -n "$r" ]] && spec_rules+=("$r")
    done < <(parse_spec_section "$spec_file" "Rules")

    # Filesystem rule not in spec → append to spec
    for rule_name in "${fs_rules[@]+"${fs_rules[@]}"}"; do
        local found=0
        for r in "${spec_rules[@]+"${spec_rules[@]}"}"; do
            [[ "$r" == "$rule_name" ]] && found=1 && break
        done
        if [[ $found -eq 0 ]]; then
            local rule_desc
            rule_desc=$(extract_description "${plugin_dir}/rules/${rule_name}.md")
            ensure_spec_section "$spec_file" "Rules"
            append_to_section "$spec_file" "Rules" "- \`${rule_name}\` — ${rule_desc}"
            log_change "${rel_path}/SPEC.md: added rule '${rule_name}'"
        fi
    done

    # Spec rule not in filesystem → create placeholder
    for rule_name in "${spec_rules[@]+"${spec_rules[@]}"}"; do
        local found=0
        for r in "${fs_rules[@]+"${fs_rules[@]}"}"; do
            [[ "$r" == "$rule_name" ]] && found=1 && break
        done
        if [[ $found -eq 0 ]]; then
            local rules_dir="${plugin_dir}/rules"
            mkdir -p "$rules_dir"
            local rule_file="${rules_dir}/${rule_name}.md"
            if [[ ! -f "$rule_file" ]]; then
                printf '# %s\n\n_description needed_\n' "$rule_name" > "$rule_file"
                log_change "${rel_path}/rules/${rule_name}.md: created (from spec)"
            fi
        fi
    done

    # --- Sync Commands ---
    local fs_commands=()
    while IFS= read -r c; do
        [[ -n "$c" ]] && fs_commands+=("$c")
    done < <(scan_commands "$plugin_dir")

    local spec_commands=()
    while IFS= read -r c; do
        [[ -n "$c" ]] && spec_commands+=("$c")
    done < <(parse_spec_section "$spec_file" "Commands")

    # Filesystem command not in spec → append to spec
    for cmd_name in "${fs_commands[@]+"${fs_commands[@]}"}"; do
        local found=0
        for c in "${spec_commands[@]+"${spec_commands[@]}"}"; do
            [[ "$c" == "$cmd_name" ]] && found=1 && break
        done
        if [[ $found -eq 0 ]]; then
            local cmd_desc
            cmd_desc=$(extract_description "${plugin_dir}/commands/${cmd_name}.md")
            ensure_spec_section "$spec_file" "Commands"
            append_to_section "$spec_file" "Commands" "- \`${cmd_name}\` — ${cmd_desc}"
            log_change "${rel_path}/SPEC.md: added command '${cmd_name}'"
        fi
    done

    # Spec command not in filesystem → create placeholder
    for cmd_name in "${spec_commands[@]+"${spec_commands[@]}"}"; do
        local found=0
        for c in "${fs_commands[@]+"${fs_commands[@]}"}"; do
            [[ "$c" == "$cmd_name" ]] && found=1 && break
        done
        if [[ $found -eq 0 ]]; then
            local commands_dir="${plugin_dir}/commands"
            mkdir -p "$commands_dir"
            local cmd_file="${commands_dir}/${cmd_name}.md"
            if [[ ! -f "$cmd_file" ]]; then
                printf '# %s\n\n_description needed_\n' "$cmd_name" > "$cmd_file"
                log_change "${rel_path}/commands/${cmd_name}.md: created (from spec)"
            fi
        fi
    done

    # --- Sync Hooks ---
    # For hooks, we compare by hook type (the key in the SPEC.md hooks section)
    local fs_hook_types=()
    while IFS= read -r h; do
        [[ -n "$h" ]] && fs_hook_types+=("$(echo "$h" | cut -d'|' -f1)")
    done < <(scan_hooks "$plugin_dir")

    local spec_hook_types=()
    while IFS= read -r h; do
        [[ -n "$h" ]] && spec_hook_types+=("$h")
    done < <(parse_spec_section "$spec_file" "Hooks")

    # Filesystem hook not in spec → append to spec
    local hooks_raw
    hooks_raw=$(scan_hooks "$plugin_dir")
    while IFS= read -r hook_line; do
        [[ -z "$hook_line" ]] && continue
        IFS='|' read -r hook_type script_type hook_desc <<< "$hook_line"
        local found=0
        for h in "${spec_hook_types[@]+"${spec_hook_types[@]}"}"; do
            [[ "$h" == "$hook_type" ]] && found=1 && break
        done
        if [[ $found -eq 0 ]]; then
            ensure_spec_section "$spec_file" "Hooks"
            append_to_section "$spec_file" "Hooks" "- \`${hook_type}\` (\`${script_type}\`) — ${hook_desc}"
            log_change "${rel_path}/SPEC.md: added hook '${hook_type}'"
        fi
    done <<< "$hooks_raw"

    # Note: we do NOT create hooks in the filesystem from spec entries
    # (hooks are more complex than skills/rules and need real implementation)
}

# Main: iterate over plugin directories
for plugin_dir in "$PLUGINS_DIR"/*/; do
    [[ -d "$plugin_dir" ]] || continue
    plugin_basename=$(basename "$plugin_dir")

    # Skip the specs/ directory if it exists
    [[ "$plugin_basename" == "specs" ]] && continue

    process_plugin "$plugin_dir"
done

if [[ ${#CHANGES[@]} -eq 0 ]]; then
    echo "No changes needed — all SPEC.md files are in sync."
else
    echo ""
    echo "Total changes: ${#CHANGES[@]}"
fi
