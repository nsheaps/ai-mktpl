#!/usr/bin/env python3
"""
Bidirectional sync between plugin SPEC.md files and the file system.

Run from the repo root:
    python3 .claude/skills/spec-sync/sync.py

For each plugin with a SPEC.md:
- FS items not in SPEC → added to SPEC
- SPEC items not in FS → created as minimal placeholder files
- Items in both → left alone
- Deletion from both → must be done manually
"""

import json
import os
import re
import sys
from pathlib import Path
from typing import Optional


PLUGINS_DIR = Path("plugins")
SKIP_DIRS = {"specs", "CLAUDE.md"}

SECTION_SKILLS = "Skills"
SECTION_RULES = "Rules"
SECTION_HOOKS = "Hooks"
SECTION_COMMANDS = "Commands"
ALL_SECTIONS = [SECTION_SKILLS, SECTION_RULES, SECTION_HOOKS, SECTION_COMMANDS]

TRUNCATE_LEN = 120


def truncate(s: str, n: int = TRUNCATE_LEN) -> str:
    if len(s) <= n:
        return s
    return s[:n].rstrip() + "..."


def read_yaml_frontmatter_field(path: Path, field: str) -> Optional[str]:
    """Read a single field from YAML frontmatter (simple key: value parsing)."""
    try:
        text = path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return None

    if not text.startswith("---"):
        return None

    # Find end of frontmatter
    end = text.find("\n---", 3)
    if end == -1:
        return None

    frontmatter = text[3:end]

    # Handle multi-line values (field: |\n  line1\n  line2)
    pattern = rf"^{re.escape(field)}\s*:\s*\|?\s*\n((?:[ \t]+.+\n?)+)"
    m = re.search(pattern, frontmatter, re.MULTILINE)
    if m:
        # Multi-line: join lines, strip leading spaces
        lines = [line.strip() for line in m.group(1).splitlines()]
        return " ".join(lines).strip()

    # Single-line: field: value
    pattern_single = rf"^{re.escape(field)}\s*:\s*>?\s*(.+)$"
    m = re.search(pattern_single, frontmatter, re.MULTILINE)
    if m:
        return m.group(1).strip().strip('"\'')

    return None


def get_skill_description(skill_dir: Path) -> Optional[str]:
    skill_md = skill_dir / "SKILL.md"
    if not skill_md.exists():
        return None
    desc = read_yaml_frontmatter_field(skill_md, "description")
    if desc:
        return truncate(desc)
    return None


def get_rule_description(rule_file: Path) -> Optional[str]:
    try:
        text = rule_file.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return None

    for line in text.splitlines():
        line = line.strip()
        if not line:
            continue
        if line.startswith("#"):
            continue
        # Strip bold markers
        line = line.replace("**", "")
        # Strip leading list markers
        line = re.sub(r"^[-*]\s*", "", line)
        if line:
            return truncate(line)
    return None


def get_command_description(command_file: Path) -> Optional[str]:
    desc = read_yaml_frontmatter_field(command_file, "description")
    if desc:
        return truncate(desc)
    return None


def parse_hooks_json(hooks_json: Path) -> tuple[Optional[str], dict[str, str]]:
    """
    Returns (overall_description, {event_name: hook_type}).
    hook_type comes from the first hook's 'type' field within each event.
    """
    try:
        data = json.loads(hooks_json.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None, {}

    overall_desc = data.get("description")
    hooks_data = data.get("hooks", {})
    result = {}
    for event_name, hook_list in hooks_data.items():
        # Find first hook entry with a 'type' field
        hook_type = None
        for entry in hook_list:
            # Each entry may have a 'hooks' sub-list
            sub_hooks = entry.get("hooks", [entry])
            for h in sub_hooks:
                if "type" in h:
                    hook_type = h["type"]
                    break
            if hook_type:
                break
        result[event_name] = hook_type or "bash"

    return overall_desc, result


# ---------------------------------------------------------------------------
# SPEC.md parsing
# ---------------------------------------------------------------------------

def parse_spec_md(spec_path: Path) -> dict[str, dict[str, str]]:
    """
    Parse SPEC.md and return:
    {
      "Skills": {"skill-name": "description", ...},
      "Rules":  {"rule-name":  "description", ...},
      "Hooks":  {"EventName":  "description", ...},
      "Commands": {"command-name": "description", ...},
    }
    Hook keys are stored as "EventName" (without type suffix).
    """
    result: dict[str, dict[str, str]] = {s: {} for s in ALL_SECTIONS}

    try:
        text = spec_path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return result

    current_section = None
    for line in text.splitlines():
        # Section header
        m = re.match(r"^## (.+)$", line)
        if m:
            heading = m.group(1).strip()
            current_section = heading if heading in ALL_SECTIONS else None
            continue

        if current_section is None:
            continue

        # Item line: - `name` — description
        # For hooks: - `EventName` (`type`) — description
        m = re.match(r"^- `([^`]+)`(?:\s+\(`[^`]+`\))?\s*(?:—\s*(.+))?$", line)
        if m:
            name = m.group(1).strip()
            desc = (m.group(2) or "").strip()
            result[current_section][name] = desc

    return result


# ---------------------------------------------------------------------------
# SPEC.md writing helpers
# ---------------------------------------------------------------------------

def ensure_section(lines: list[str], section: str) -> int:
    """
    Ensure a ## section exists in lines. Returns the index of the last item
    line in that section (or the line just before the next section / EOF if empty).
    """
    section_header = f"## {section}"
    for i, line in enumerate(lines):
        if line.strip() == section_header:
            # Find last item line in this section
            j = i + 1
            last_item = i  # default: right after header
            while j < len(lines):
                if re.match(r"^## ", lines[j]):
                    break
                if re.match(r"^- `", lines[j]):
                    last_item = j
                j += 1
            return last_item

    # Section doesn't exist — append it
    # Add blank line before new section if needed
    if lines and lines[-1].strip():
        lines.append("")
    lines.append(section_header)
    lines.append("")
    return len(lines) - 1  # insertion point is after the blank


def insert_spec_item(lines: list[str], section: str, item_line: str) -> None:
    """Insert item_line into the given section in lines (in-place)."""
    section_header = f"## {section}"
    in_section = False
    last_item_idx = None

    for i, line in enumerate(lines):
        if line.strip() == section_header:
            in_section = True
            continue
        if in_section:
            if re.match(r"^## ", line):
                break
            if re.match(r"^- `", line):
                last_item_idx = i

    if last_item_idx is not None:
        lines.insert(last_item_idx + 1, item_line)
    else:
        # Section exists but has no items yet — insert after header (+ blank)
        for i, line in enumerate(lines):
            if line.strip() == section_header:
                # Find insertion point: skip blank lines right after header
                j = i + 1
                while j < len(lines) and not lines[j].strip():
                    j += 1
                lines.insert(j, item_line)
                return
        # Section header not found — append section + item
        if lines and lines[-1].strip():
            lines.append("")
        lines.append(section_header)
        lines.append("")
        lines.append(item_line)


# ---------------------------------------------------------------------------
# Main sync logic
# ---------------------------------------------------------------------------

def sync_plugin(plugin_dir: Path, changes: list[str]) -> None:
    spec_path = plugin_dir / "SPEC.md"
    if not spec_path.exists():
        return

    spec = parse_spec_md(spec_path)
    spec_lines = spec_path.read_text(encoding="utf-8").splitlines()
    modified = False

    # -----------------------------------------------------------------------
    # Skills
    # -----------------------------------------------------------------------
    skills_dir = plugin_dir / "skills"
    if skills_dir.is_dir():
        spec_skills = spec[SECTION_SKILLS]
        for skill_dir in sorted(skills_dir.iterdir()):
            if not skill_dir.is_dir():
                continue
            name = skill_dir.name
            if name not in spec_skills:
                # FS → SPEC
                desc = get_skill_description(skill_dir) or "(no description — fill in manually)"
                item_line = f"- `{name}` — {desc}"
                insert_spec_item(spec_lines, SECTION_SKILLS, item_line)
                modified = True
                changes.append(f"  [SPEC+] {plugin_dir.name}/skills/{name}  →  added to SPEC.md")

        for name in sorted(spec_skills):
            skill_dir = skills_dir / name
            if not skill_dir.exists():
                # SPEC → FS
                skill_dir.mkdir(parents=True, exist_ok=True)
                desc = spec_skills[name] or ""
                skill_md = skill_dir / "SKILL.md"
                skill_md.write_text(
                    f"---\nname: {name}\ndescription: |\n  {desc}\n---\n\n# {name}\n\n(Placeholder — fill in content.)\n",
                    encoding="utf-8",
                )
                changes.append(f"  [FS+]   {plugin_dir.name}/skills/{name}/SKILL.md  ←  created from SPEC.md")

    # -----------------------------------------------------------------------
    # Rules
    # -----------------------------------------------------------------------
    rules_dir = plugin_dir / "rules"
    if rules_dir.is_dir():
        spec_rules = spec[SECTION_RULES]
        for item in sorted(rules_dir.iterdir()):
            if item.is_dir():
                # Skip subdirectories (e.g. rules/glossary/)
                continue
            if item.suffix != ".md":
                continue
            name = item.stem
            if name not in spec_rules:
                # FS → SPEC
                desc = get_rule_description(item) or "(no description — fill in manually)"
                item_line = f"- `{name}` — {desc}"
                insert_spec_item(spec_lines, SECTION_RULES, item_line)
                modified = True
                changes.append(f"  [SPEC+] {plugin_dir.name}/rules/{item.name}  →  added to SPEC.md")

        for name in sorted(spec_rules):
            rule_file = rules_dir / f"{name}.md"
            if not rule_file.exists():
                # SPEC → FS
                desc = spec_rules[name] or ""
                rule_file.write_text(
                    f"# {name}\n\n{desc}\n\n(Placeholder — fill in content.)\n",
                    encoding="utf-8",
                )
                changes.append(f"  [FS+]   {plugin_dir.name}/rules/{name}.md  ←  created from SPEC.md")

    # -----------------------------------------------------------------------
    # Commands
    # -----------------------------------------------------------------------
    commands_dir = plugin_dir / "commands"
    if commands_dir.is_dir():
        spec_commands = spec[SECTION_COMMANDS]
        for item in sorted(commands_dir.iterdir()):
            if not item.is_file() or item.suffix != ".md":
                continue
            name = item.stem
            if name not in spec_commands:
                # FS → SPEC
                desc = get_command_description(item) or "(no description — fill in manually)"
                item_line = f"- `{name}` — {desc}"
                insert_spec_item(spec_lines, SECTION_COMMANDS, item_line)
                modified = True
                changes.append(f"  [SPEC+] {plugin_dir.name}/commands/{item.name}  →  added to SPEC.md")

        for name in sorted(spec_commands):
            cmd_file = commands_dir / f"{name}.md"
            if not cmd_file.exists():
                # SPEC → FS
                desc = spec_commands[name] or ""
                cmd_file.write_text(
                    f"---\nname: {name}\ndescription: {desc}\n---\n\n# {name}\n\n(Placeholder — fill in content.)\n",
                    encoding="utf-8",
                )
                changes.append(f"  [FS+]   {plugin_dir.name}/commands/{name}.md  ←  created from SPEC.md")

    # -----------------------------------------------------------------------
    # Hooks
    # -----------------------------------------------------------------------
    hooks_json = plugin_dir / "hooks" / "hooks.json"
    if hooks_json.exists():
        overall_desc, fs_hooks = parse_hooks_json(hooks_json)
        spec_hooks = spec[SECTION_HOOKS]

        for event_name, hook_type in sorted(fs_hooks.items()):
            if event_name not in spec_hooks:
                # FS → SPEC
                desc = overall_desc or "(no description — fill in manually)"
                item_line = f"- `{event_name}` (`{hook_type}`) — {truncate(desc)}"
                insert_spec_item(spec_lines, SECTION_HOOKS, item_line)
                modified = True
                changes.append(f"  [SPEC+] {plugin_dir.name}/hooks/{event_name}  →  added to SPEC.md")

        for event_name in sorted(spec_hooks):
            if event_name not in fs_hooks:
                # SPEC → FS: skip (can't easily recreate hooks.json entries)
                changes.append(
                    f"  [SKIP]  {plugin_dir.name}/hooks/{event_name} listed in SPEC but not in hooks.json — skipped (fix manually)"
                )

    # -----------------------------------------------------------------------
    # Write updated SPEC if modified
    # -----------------------------------------------------------------------
    if modified:
        spec_path.write_text("\n".join(spec_lines) + "\n", encoding="utf-8")


def main() -> None:
    if not PLUGINS_DIR.exists():
        print("ERROR: plugins/ directory not found. Run from repo root.", file=sys.stderr)
        sys.exit(1)

    all_changes: list[str] = []

    for plugin_dir in sorted(PLUGINS_DIR.iterdir()):
        if not plugin_dir.is_dir():
            continue
        if plugin_dir.name in SKIP_DIRS:
            continue

        plugin_changes: list[str] = []
        sync_plugin(plugin_dir, plugin_changes)

        if plugin_changes:
            all_changes.append(f"\n{plugin_dir.name}:")
            all_changes.extend(plugin_changes)

    if all_changes:
        print("Spec sync changes:")
        print("\n".join(all_changes))
    else:
        print("Nothing to sync — all SPEC.md files are in sync with the file system.")


if __name__ == "__main__":
    main()
