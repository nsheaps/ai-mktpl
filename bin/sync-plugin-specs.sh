#!/usr/bin/env bash
# sync-plugin-specs.sh — Sync SPEC.md files with the plugin filesystem
#
# For each plugin, ensures SPEC.md reflects what's on disk:
#   - Missing SPEC.md → generate from filesystem with placeholder descriptions
#   - FS item not in spec → insert entry into spec section
#   - Spec item not in FS → create minimal skeleton on disk
#   - Both exist → leave completely alone (no description updates)
#
# Usage:
#   sync-plugin-specs.sh [--plugin <name>]
#
#   --plugin <name>   Run only on the named plugin (directory under plugins/)
#                     Default: run on all plugins

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGINS_DIR="${SCRIPT_DIR}/../plugins"
PLUGINS_DIR="$(cd "$PLUGINS_DIR" && pwd)"

PLUGIN_FILTER=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --plugin)
            PLUGIN_FILTER="$2"
            shift 2
            ;;
        *)
            echo "Unknown argument: $1" >&2
            echo "Usage: $0 [--plugin <name>]" >&2
            exit 1
            ;;
    esac
done

# ---------------------------------------------------------------------------
# Description extraction
# ---------------------------------------------------------------------------

# Extract description from a markdown file.
# Priority:
#   1. YAML frontmatter `description:` field (handles block scalars via joining)
#   2. First non-empty, non-heading, non-frontmatter line
# Returns at most 120 characters (truncated with ...).
extract_description() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        echo "TODO: add description"
        return
    fi

    # Try YAML frontmatter description first using awk.
    # Handles both single-line (description: text) and block scalars (description: >\n  text).
    local yaml_desc
    yaml_desc=$(awk '
        BEGIN { in_front=0; found=0; is_block=0; buf="" }
        /^---$/ {
            if (in_front==0) { in_front=1; next }
            else { exit }
        }
        in_front && /^description:/ {
            found=1
            val=$0
            sub(/^description:[[:space:]]*/, "", val)
            # Check for block scalar indicator
            if (val ~ /^[>|]/) {
                is_block=1
                next
            }
            # Strip surrounding quotes
            gsub(/^'"'"'|'"'"'$/, "", val)
            gsub(/^"|"$/, "", val)
            if (val != "") { buf=val; exit }
            next
        }
        in_front && found && is_block && /^[[:space:]]/ {
            line=$0
            sub(/^[[:space:]]+/, "", line)
            if (line != "") {
                if (buf != "") buf=buf" "line
                else buf=line
            }
            next
        }
        in_front && found && /^[^[:space:]]/ { exit }
        END { print buf }
    ' "$file" 2>/dev/null || true)
    yaml_desc="${yaml_desc## }"
    yaml_desc="${yaml_desc%% }"

    if [[ -n "$yaml_desc" ]]; then
        if [[ ${#yaml_desc} -gt 120 ]]; then
            echo "${yaml_desc:0:120}..."
        else
            echo "$yaml_desc"
        fi
        return
    fi

    # Fall back to first non-empty, non-heading, non-frontmatter line
    local desc=""
    local in_frontmatter=0
    local first_line=1
    while IFS= read -r line; do
        if [[ "$line" == "---" ]]; then
            if [[ $first_line -eq 1 ]]; then
                in_frontmatter=1
                first_line=0
                continue
            elif [[ $in_frontmatter -eq 1 ]]; then
                in_frontmatter=0
                continue
            fi
        fi
        first_line=0
        [[ $in_frontmatter -eq 1 ]] && continue
        [[ -z "$line" ]] && continue
        [[ "$line" =~ ^#+ ]] && continue
        # Skip lines that are just bold purpose markers
        [[ "$line" =~ ^\*\*[Pp]urpose\*\* ]] && continue
        # Skip HTML comments
        [[ "$line" =~ ^\<!-- ]] && continue
        # Strip leading list/quote markers
        line="${line#- }"
        line="${line#> }"
        [[ -z "$line" ]] && continue
        desc="$line"
        break
    done < "$file"

    if [[ -z "$desc" ]]; then
        echo "TODO: add description"
        return
    fi

    if [[ ${#desc} -gt 120 ]]; then
        echo "${desc:0:120}..."
    else
        echo "$desc"
    fi
}

# ---------------------------------------------------------------------------
# Filesystem scanners
# ---------------------------------------------------------------------------

# Skills: subdirectories in skills/ OR .md files directly in skills/
scan_skills() {
    local plugin_dir="$1"
    local skills_dir="${plugin_dir}/skills"
    [[ -d "$skills_dir" ]] || return

    # Subdirectories (each is a skill)
    for entry in "$skills_dir"/*/; do
        [[ -d "$entry" ]] || continue
        basename "$entry"
    done

    # .md files directly in skills/ (e.g. agentic-guidelines.md)
    for entry in "$skills_dir"/*.md; do
        [[ -f "$entry" ]] || continue
        basename "$entry" .md
    done
}

# Hooks: event keys from hooks/hooks.json .hooks object
# Output format per line: "EventName|type|description"
scan_hooks() {
    local plugin_dir="$1"
    local hooks_json="${plugin_dir}/hooks/hooks.json"
    [[ -f "$hooks_json" ]] || return

    local top_desc
    top_desc=$(jq -r '.description // "TODO: add description"' "$hooks_json" 2>/dev/null || echo "TODO: add description")

    jq -r '.hooks | keys[]' "$hooks_json" 2>/dev/null | while IFS= read -r event; do
        [[ -z "$event" ]] && continue
        # Determine the type from first hook entry for this event
        local htype
        htype=$(jq -r --arg e "$event" '
            .hooks[$e][0].hooks[0].type // "bash"
        ' "$hooks_json" 2>/dev/null || echo "bash")
        # "command" means it's a bash script
        [[ "$htype" == "command" ]] && htype="bash"
        echo "${event}|${htype}|${top_desc}"
    done
}

# Rules: .md files in rules/ (name without extension)
scan_rules() {
    local plugin_dir="$1"
    local rules_dir="${plugin_dir}/rules"
    [[ -d "$rules_dir" ]] || return

    for entry in "$rules_dir"/*.md; do
        [[ -f "$entry" ]] || continue
        basename "$entry" .md
    done
}

# Agents: dirs OR .md files in agents/ (name without .md extension)
scan_agents() {
    local plugin_dir="$1"
    local agents_dir="${plugin_dir}/agents"
    [[ -d "$agents_dir" ]] || return

    for entry in "$agents_dir"/*/; do
        [[ -d "$entry" ]] || continue
        basename "$entry"
    done
    for entry in "$agents_dir"/*.md; do
        [[ -f "$entry" ]] || continue
        basename "$entry" .md
    done
}

# Commands: dirs OR .md files in commands/ (name without .md extension)
scan_commands() {
    local plugin_dir="$1"
    local commands_dir="${plugin_dir}/commands"
    [[ -d "$commands_dir" ]] || return

    for entry in "$commands_dir"/*/; do
        [[ -d "$entry" ]] || continue
        basename "$entry"
    done
    for entry in "$commands_dir"/*.md; do
        [[ -f "$entry" ]] || continue
        basename "$entry" .md
    done
}

# ---------------------------------------------------------------------------
# Spec parsing helpers
# ---------------------------------------------------------------------------

# Parse item names from a named section in SPEC.md.
# Matches: - `name` — ...  and  - `name` (`type`) — ...
parse_spec_section() {
    local spec_file="$1"
    local section="$2"
    [[ -f "$spec_file" ]] || return

    local in_section=0
    while IFS= read -r line; do
        if [[ "$line" =~ ^##[[:space:]]+${section}[[:space:]]*$ ]]; then
            in_section=1
            continue
        fi
        if [[ $in_section -eq 1 ]] && [[ "$line" =~ ^## ]]; then
            break
        fi
        if [[ $in_section -eq 1 ]] && [[ "$line" =~ ^\-[[:space:]]+\`([^\`]+)\` ]]; then
            echo "${BASH_REMATCH[1]}"
        fi
    done < "$spec_file"
}

# Return 0 if a section heading exists, 1 otherwise
spec_has_section() {
    local spec_file="$1"
    local section="$2"
    grep -qE "^## ${section}[[:space:]]*$" "$spec_file" 2>/dev/null
}

# ---------------------------------------------------------------------------
# Spec modification helpers
# ---------------------------------------------------------------------------

# Append a section at the end of SPEC.md if it doesn't exist
ensure_spec_section() {
    local spec_file="$1"
    local section="$2"
    if ! spec_has_section "$spec_file" "$section"; then
        printf '\n## %s\n' "$section" >> "$spec_file"
    fi
}

# Insert item_line into section, before the next ## heading (or at EOF).
# Uses awk for reliable in-place editing via temp file.
append_to_section() {
    local spec_file="$1"
    local section="$2"
    local item_line="$3"

    local tmp
    tmp=$(mktemp)

    awk -v target="## ${section}" -v newitem="$item_line" '
        BEGIN { in_sect=0; done=0 }
        /^## / {
            if (in_sect && !done) {
                print newitem
                print ""
                done=1
            }
            in_sect = ($0 == target)
        }
        { print }
        END {
            if (in_sect && !done) {
                print newitem
            }
        }
    ' "$spec_file" > "$tmp"

    mv "$tmp" "$spec_file"
}

# ---------------------------------------------------------------------------
# Array membership helper
# ---------------------------------------------------------------------------

array_contains() {
    local needle="$1"
    shift
    local item
    for item in "$@"; do
        [[ "$item" == "$needle" ]] && return 0
    done
    return 1
}

# ---------------------------------------------------------------------------
# SPEC.md generation for missing files
# ---------------------------------------------------------------------------

generate_spec() {
    local plugin_dir="$1"
    local spec_file="${plugin_dir}/SPEC.md"
    local plugin_name
    plugin_name=$(basename "$plugin_dir")

    {
        echo "# Plugin: ${plugin_name}"
        echo ""
        echo "**Purpose**: TODO: add description"
        echo ""

        # Skills
        local skills_list=()
        while IFS= read -r name; do
            [[ -n "$name" ]] && skills_list+=("$name")
        done < <(scan_skills "$plugin_dir")

        if [[ ${#skills_list[@]} -gt 0 ]]; then
            echo "## Skills"
            echo ""
            for name in "${skills_list[@]}"; do
                local skill_file="${plugin_dir}/skills/${name}/SKILL.md"
                [[ ! -f "$skill_file" ]] && skill_file="${plugin_dir}/skills/${name}.md"
                local desc
                desc=$(extract_description "$skill_file")
                echo "- \`${name}\` — ${desc}"
            done
            echo ""
        fi

        # Hooks
        local hooks_output
        hooks_output=$(scan_hooks "$plugin_dir" || true)
        if [[ -n "$hooks_output" ]]; then
            echo "## Hooks"
            echo ""
            while IFS='|' read -r event htype desc; do
                [[ -z "$event" ]] && continue
                echo "- \`${event}\` (\`${htype}\`) — ${desc}"
            done <<< "$hooks_output"
            echo ""
        fi

        # Rules
        local rules_list=()
        while IFS= read -r name; do
            [[ -n "$name" ]] && rules_list+=("$name")
        done < <(scan_rules "$plugin_dir")

        if [[ ${#rules_list[@]} -gt 0 ]]; then
            echo "## Rules"
            echo ""
            for name in "${rules_list[@]}"; do
                local desc
                desc=$(extract_description "${plugin_dir}/rules/${name}.md")
                echo "- \`${name}\` — ${desc}"
            done
            echo ""
        fi

        # Agents
        local agents_list=()
        while IFS= read -r name; do
            [[ -n "$name" ]] && agents_list+=("$name")
        done < <(scan_agents "$plugin_dir")

        if [[ ${#agents_list[@]} -gt 0 ]]; then
            echo "## Agents"
            echo ""
            for name in "${agents_list[@]}"; do
                local agent_file="${plugin_dir}/agents/${name}.md"
                [[ ! -f "$agent_file" ]] && agent_file="${plugin_dir}/agents/${name}/README.md"
                local desc
                desc=$(extract_description "$agent_file")
                echo "- \`${name}\` — ${desc}"
            done
            echo ""
        fi

        # Commands
        local commands_list=()
        while IFS= read -r name; do
            [[ -n "$name" ]] && commands_list+=("$name")
        done < <(scan_commands "$plugin_dir")

        if [[ ${#commands_list[@]} -gt 0 ]]; then
            echo "## Commands"
            echo ""
            for name in "${commands_list[@]}"; do
                local cmd_file="${plugin_dir}/commands/${name}.md"
                [[ ! -f "$cmd_file" ]] && cmd_file="${plugin_dir}/commands/${name}/README.md"
                local desc
                desc=$(extract_description "$cmd_file")
                echo "- \`${name}\` — ${desc}"
            done
            echo ""
        fi
    } > "$spec_file"
}

# ---------------------------------------------------------------------------
# Main plugin processor — returns change lines on stdout
# ---------------------------------------------------------------------------

process_plugin() {
    local plugin_dir="$1"
    local plugin_name
    plugin_name=$(basename "$plugin_dir")
    local spec_file="${plugin_dir}/SPEC.md"
    local prefix="plugins/${plugin_name}"

    # Generate SPEC.md from scratch if missing
    if [[ ! -f "$spec_file" ]]; then
        generate_spec "$plugin_dir"
        echo "${prefix}/SPEC.md: generated (new)"
        return
    fi

    # ---- Skills ----
    local fs_skills=()
    while IFS= read -r name; do
        [[ -n "$name" ]] && fs_skills+=("$name")
    done < <(scan_skills "$plugin_dir")

    local spec_skills=()
    while IFS= read -r name; do
        [[ -n "$name" ]] && spec_skills+=("$name")
    done < <(parse_spec_section "$spec_file" "Skills")

    for name in "${fs_skills[@]+"${fs_skills[@]}"}"; do
        if ! array_contains "$name" "${spec_skills[@]+"${spec_skills[@]}"}"; then
            local skill_file="${plugin_dir}/skills/${name}/SKILL.md"
            [[ ! -f "$skill_file" ]] && skill_file="${plugin_dir}/skills/${name}.md"
            local desc
            desc=$(extract_description "$skill_file")
            ensure_spec_section "$spec_file" "Skills"
            append_to_section "$spec_file" "Skills" "- \`${name}\` — ${desc}"
            echo "${prefix}/SPEC.md: added skill '${name}'"
        fi
    done

    for name in "${spec_skills[@]+"${spec_skills[@]}"}"; do
        if ! array_contains "$name" "${fs_skills[@]+"${fs_skills[@]}"}"; then
            local skill_dir="${plugin_dir}/skills/${name}"
            if [[ ! -d "$skill_dir" ]] && [[ ! -f "${plugin_dir}/skills/${name}.md" ]]; then
                mkdir -p "$skill_dir"
                printf -- '---\nname: %s\ndescription: TODO: add description\n---\n\n# %s\n\nTODO: add skill content\n' \
                    "$name" "$name" > "${skill_dir}/SKILL.md"
                echo "${prefix}/skills/${name}/SKILL.md: created (from spec)"
            fi
        fi
    done

    # ---- Hooks ----
    local hooks_raw
    hooks_raw=$(scan_hooks "$plugin_dir" || true)

    local spec_hook_types=()
    while IFS= read -r name; do
        [[ -n "$name" ]] && spec_hook_types+=("$name")
    done < <(parse_spec_section "$spec_file" "Hooks")

    if [[ -n "$hooks_raw" ]]; then
        while IFS='|' read -r event htype desc; do
            [[ -z "$event" ]] && continue
            if ! array_contains "$event" "${spec_hook_types[@]+"${spec_hook_types[@]}"}"; then
                ensure_spec_section "$spec_file" "Hooks"
                append_to_section "$spec_file" "Hooks" "- \`${event}\` (\`${htype}\`) — ${desc}"
                echo "${prefix}/SPEC.md: added hook '${event}'"
            fi
        done <<< "$hooks_raw"
    fi
    # hooks.json is authoritative — no skeleton creation for missing hooks

    # ---- Rules ----
    local fs_rules=()
    while IFS= read -r name; do
        [[ -n "$name" ]] && fs_rules+=("$name")
    done < <(scan_rules "$plugin_dir")

    local spec_rules=()
    while IFS= read -r name; do
        [[ -n "$name" ]] && spec_rules+=("$name")
    done < <(parse_spec_section "$spec_file" "Rules")

    for name in "${fs_rules[@]+"${fs_rules[@]}"}"; do
        if ! array_contains "$name" "${spec_rules[@]+"${spec_rules[@]}"}"; then
            local desc
            desc=$(extract_description "${plugin_dir}/rules/${name}.md")
            ensure_spec_section "$spec_file" "Rules"
            append_to_section "$spec_file" "Rules" "- \`${name}\` — ${desc}"
            echo "${prefix}/SPEC.md: added rule '${name}'"
        fi
    done

    for name in "${spec_rules[@]+"${spec_rules[@]}"}"; do
        if ! array_contains "$name" "${fs_rules[@]+"${fs_rules[@]}"}"; then
            local rule_file="${plugin_dir}/rules/${name}.md"
            if [[ ! -f "$rule_file" ]]; then
                mkdir -p "${plugin_dir}/rules"
                printf '# %s\n\nTODO: add description\n' "$name" > "$rule_file"
                echo "${prefix}/rules/${name}.md: created (from spec)"
            fi
        fi
    done

    # ---- Agents ----
    local fs_agents=()
    while IFS= read -r name; do
        [[ -n "$name" ]] && fs_agents+=("$name")
    done < <(scan_agents "$plugin_dir")

    local spec_agents=()
    while IFS= read -r name; do
        [[ -n "$name" ]] && spec_agents+=("$name")
    done < <(parse_spec_section "$spec_file" "Agents")

    for name in "${fs_agents[@]+"${fs_agents[@]}"}"; do
        if ! array_contains "$name" "${spec_agents[@]+"${spec_agents[@]}"}"; then
            local agent_file="${plugin_dir}/agents/${name}.md"
            [[ ! -f "$agent_file" ]] && agent_file="${plugin_dir}/agents/${name}/README.md"
            local desc
            desc=$(extract_description "$agent_file")
            ensure_spec_section "$spec_file" "Agents"
            append_to_section "$spec_file" "Agents" "- \`${name}\` — ${desc}"
            echo "${prefix}/SPEC.md: added agent '${name}'"
        fi
    done

    for name in "${spec_agents[@]+"${spec_agents[@]}"}"; do
        if ! array_contains "$name" "${fs_agents[@]+"${fs_agents[@]}"}"; then
            local agent_file="${plugin_dir}/agents/${name}.md"
            if [[ ! -f "$agent_file" ]] && [[ ! -d "${plugin_dir}/agents/${name}" ]]; then
                mkdir -p "${plugin_dir}/agents"
                printf -- '---\nname: %s\ndescription: TODO: add description\n---\n\nTODO: add agent content\n' \
                    "$name" > "$agent_file"
                echo "${prefix}/agents/${name}.md: created (from spec)"
            fi
        fi
    done

    # ---- Commands ----
    local fs_commands=()
    while IFS= read -r name; do
        [[ -n "$name" ]] && fs_commands+=("$name")
    done < <(scan_commands "$plugin_dir")

    local spec_commands=()
    while IFS= read -r name; do
        [[ -n "$name" ]] && spec_commands+=("$name")
    done < <(parse_spec_section "$spec_file" "Commands")

    for name in "${fs_commands[@]+"${fs_commands[@]}"}"; do
        if ! array_contains "$name" "${spec_commands[@]+"${spec_commands[@]}"}"; then
            local cmd_file="${plugin_dir}/commands/${name}.md"
            [[ ! -f "$cmd_file" ]] && cmd_file="${plugin_dir}/commands/${name}/README.md"
            local desc
            desc=$(extract_description "$cmd_file")
            ensure_spec_section "$spec_file" "Commands"
            append_to_section "$spec_file" "Commands" "- \`${name}\` — ${desc}"
            echo "${prefix}/SPEC.md: added command '${name}'"
        fi
    done

    for name in "${spec_commands[@]+"${spec_commands[@]}"}"; do
        if ! array_contains "$name" "${fs_commands[@]+"${fs_commands[@]}"}"; then
            local cmd_file="${plugin_dir}/commands/${name}.md"
            if [[ ! -f "$cmd_file" ]] && [[ ! -d "${plugin_dir}/commands/${name}" ]]; then
                mkdir -p "${plugin_dir}/commands"
                printf -- '---\nname: %s\ndescription: TODO: add description\n---\n\nTODO: add command content\n' \
                    "$name" > "$cmd_file"
                echo "${prefix}/commands/${name}.md: created (from spec)"
            fi
        fi
    done
}

# ---------------------------------------------------------------------------
# Entrypoint
# ---------------------------------------------------------------------------

total_changes=0

if [[ -n "$PLUGIN_FILTER" ]]; then
    plugin_dir="${PLUGINS_DIR}/${PLUGIN_FILTER}"
    if [[ ! -d "$plugin_dir" ]]; then
        echo "Error: plugin directory not found: ${plugin_dir}" >&2
        exit 1
    fi
    while IFS= read -r line; do
        echo "$line"
        total_changes=$((total_changes + 1))
    done < <(process_plugin "$plugin_dir")
else
    for plugin_dir in "$PLUGINS_DIR"/*/; do
        [[ -d "$plugin_dir" ]] || continue
        plugin_basename=$(basename "$plugin_dir")
        # Skip non-directory entries that happen to match the glob
        [[ "$plugin_basename" == CLAUDE.md ]] && continue
        [[ -f "${plugin_dir}.claude-plugin/plugin.json" ]] || continue
        while IFS= read -r line; do
            echo "$line"
            total_changes=$((total_changes + 1))
        done < <(process_plugin "$plugin_dir")
    done
fi

echo ""
if [[ $total_changes -eq 0 ]]; then
    echo "No changes needed — all SPEC.md files are in sync."
else
    echo "Total changes: ${total_changes}"
fi
