#!/usr/bin/env python3
"""
sync-settings.py - Claude Code Settings Sync Hook

This hook synchronizes settings and files based on rules defined in syncconfig.yaml.
Supports JSON merging, file copying, symlinking, and content replacement.

Usage: Called as a SessionStart hook by Claude Code
Environment: CLAUDE_PROJECT_DIR must be set
"""

import glob as globlib
import hashlib
import json
import os
import shutil
import sys
from copy import deepcopy
from pathlib import Path
from typing import Any, Dict, List, Optional, Union

# Try to import yaml, provide fallback instructions if not available
try:
    import yaml
except ImportError:
    print(
        "Error: PyYAML is required. Install with: pip install pyyaml", file=sys.stderr
    )
    sys.exit(2)


class SyncError(Exception):
    """Custom exception for sync errors"""

    pass


def get_project_dir() -> Path:
    """Get the project directory from environment or current directory"""
    project_dir = os.environ.get("CLAUDE_PROJECT_DIR")
    if project_dir:
        return Path(project_dir)
    return Path.cwd()


def resolve_path(path: str, base_dir: Path, config_dir: Path) -> Path:
    """
    Resolve a path relative to the config directory.
    Paths starting with ./ are relative to the config directory (.claude/)
    Other paths are resolved relative to the project directory.
    """
    if path.startswith("./"):
        return (config_dir / path[2:]).resolve()
    elif path.startswith("../"):
        return (config_dir / path).resolve()
    else:
        return (base_dir / path).resolve()


def file_hash(filepath: Path) -> str:
    """Calculate SHA256 hash of a file"""
    sha256 = hashlib.sha256()
    with open(filepath, "rb") as f:
        for chunk in iter(lambda: f.read(4096), b""):
            sha256.update(chunk)
    return sha256.hexdigest()


def files_are_different(file1: Path, file2: Path) -> bool:
    """Check if two files have different contents"""
    if not file1.exists() or not file2.exists():
        return True
    return file_hash(file1) != file_hash(file2)


def deep_merge(base: Dict, overlay: Dict, only_keys: Optional[List] = None) -> Dict:
    """
    Deep merge overlay into base, returning new dict.
    If only_keys is specified, only merge those keys from overlay.
    """
    result = deepcopy(base)

    keys_to_merge = only_keys if only_keys else overlay.keys()

    for key in keys_to_merge:
        if key not in overlay:
            continue

        if (
            key in result
            and isinstance(result[key], dict)
            and isinstance(overlay[key], dict)
        ):
            result[key] = deep_merge(result[key], overlay[key])
        else:
            result[key] = deepcopy(overlay[key])

    return result


def filter_by_only(data: Dict, only_spec: List[Dict]) -> Dict:
    """
    Filter data to only include keys specified in the 'only' spec.

    only_spec format:
    - key: "keyname"
      only: "subkey"  # or ["subkey1", "subkey2"]
    - key: "otherkey"
    """
    if not only_spec:
        return data

    result = {}

    for spec in only_spec:
        key = spec.get("key")
        if not key or key not in data:
            continue

        sub_only = spec.get("only")
        if sub_only and isinstance(data[key], dict):
            # Filter sub-keys
            if isinstance(sub_only, str):
                sub_only = [sub_only]
            result[key] = {
                k: deepcopy(data[key][k]) for k in sub_only if k in data[key]
            }
        else:
            # Include entire key
            result[key] = deepcopy(data[key])

    return result


def process_merge_rule(rule: Dict, project_dir: Path, config_dir: Path) -> None:
    """
    Process a merge rule for JSON files.
    Merges source into target, optionally filtering by 'only' keys.
    """
    source_path = resolve_path(rule["source"], project_dir, config_dir)
    target_path = resolve_path(rule["target"], project_dir, config_dir)
    only_spec = rule.get("only", [])

    if not source_path.exists():
        print(f"  Skipping: source not found: {source_path}")
        return

    # Load source JSON
    with open(source_path, "r") as f:
        source_data = json.load(f)

    # Filter source data if 'only' is specified
    if only_spec:
        source_data = filter_by_only(source_data, only_spec)

    # Load or create target JSON
    if target_path.exists():
        with open(target_path, "r") as f:
            target_data = json.load(f)
    else:
        target_data = {}
        target_path.parent.mkdir(parents=True, exist_ok=True)

    # Merge source into target
    merged_data = deep_merge(target_data, source_data)

    # Write merged result
    with open(target_path, "w") as f:
        json.dump(merged_data, f, indent=2)
        f.write("\n")

    print(f"  Merged: {source_path.name} -> {target_path.name}")


def process_sync_rule(rule: Dict, project_dir: Path, config_dir: Path) -> None:
    """
    Process a sync rule for files/directories.
    Supports glob patterns and various sync modes.
    """
    source_pattern = rule["source"]
    target_path_str = rule["target"]
    sync_mode = rule.get("sync-mode", "copy")
    if_present = rule.get("if-present", "do-nothing")

    # Resolve the source pattern
    if source_pattern.startswith("./"):
        source_base = config_dir
        pattern = source_pattern[2:]
    elif source_pattern.startswith("../"):
        source_base = config_dir.parent
        # Count the number of ../ and adjust
        parts = source_pattern.split("/")
        up_count = 0
        remaining_parts = []
        for part in parts:
            if part == "..":
                up_count += 1
            else:
                remaining_parts.append(part)
        source_base = config_dir
        for _ in range(up_count):
            source_base = source_base.parent
        pattern = "/".join(remaining_parts)
    else:
        source_base = project_dir
        pattern = source_pattern

    # Find matching source files
    full_pattern = str(source_base / pattern)
    source_files = globlib.glob(full_pattern, recursive=True)

    if not source_files:
        print(f"  Skipping: no files match pattern: {source_pattern}")
        return

    # Resolve target path
    target_path = resolve_path(target_path_str, project_dir, config_dir)

    # Determine if target is a directory (ends with / or multiple sources)
    target_is_dir = target_path_str.endswith("/") or len(source_files) > 1

    if target_is_dir:
        target_path.mkdir(parents=True, exist_ok=True)

    for source_file in source_files:
        source_path = Path(source_file)
        if not source_path.is_file():
            continue

        if target_is_dir:
            dest_path = target_path / source_path.name
        else:
            dest_path = target_path
            dest_path.parent.mkdir(parents=True, exist_ok=True)

        # Handle existing files
        if dest_path.exists():
            if if_present == "do-nothing":
                print(f"  Skipping (exists): {dest_path.name}")
                continue
            elif if_present == "error-if-different":
                if files_are_different(source_path, dest_path):
                    raise SyncError(f"File exists and differs: {dest_path}")
                print(f"  Skipping (identical): {dest_path.name}")
                continue
            elif if_present == "replace":
                if dest_path.is_symlink():
                    dest_path.unlink()
                elif dest_path.is_file():
                    dest_path.unlink()

        # Perform the sync operation
        if sync_mode == "symlink":
            # Create relative symlink if possible
            try:
                rel_path = os.path.relpath(source_path, dest_path.parent)
                dest_path.symlink_to(rel_path)
            except ValueError:
                # Different drives on Windows, use absolute path
                dest_path.symlink_to(source_path)
            print(f"  Symlinked: {source_path.name} -> {dest_path.name}")
        else:  # copy
            shutil.copy2(source_path, dest_path)
            print(f"  Copied: {source_path.name} -> {dest_path.name}")


def process_source_only_rule(rule: Dict, project_dir: Path, config_dir: Path) -> None:
    """
    Process a source-only rule.
    Ensures target directory only contains files from source directory.
    """
    source_pattern = rule["source"]
    target_path_str = rule["target"]
    sync_mode = rule.get("sync-mode", "copy")

    # First, sync all source files
    sync_rule = {
        "source": source_pattern,
        "target": target_path_str,
        "sync-mode": sync_mode,
        "if-present": "replace",
    }
    process_sync_rule(sync_rule, project_dir, config_dir)

    # Then, remove files in target that aren't in source
    target_path = resolve_path(target_path_str, project_dir, config_dir)

    if not target_path.is_dir():
        return

    # Get list of source file names
    if source_pattern.startswith("./"):
        source_base = config_dir
        pattern = source_pattern[2:]
    elif source_pattern.startswith("../"):
        parts = source_pattern.split("/")
        up_count = sum(1 for p in parts if p == "..")
        remaining_parts = [p for p in parts if p != ".."]
        source_base = config_dir
        for _ in range(up_count):
            source_base = source_base.parent
        pattern = "/".join(remaining_parts)
    else:
        source_base = project_dir
        pattern = source_pattern

    full_pattern = str(source_base / pattern)
    source_files = {
        Path(f).name
        for f in globlib.glob(full_pattern, recursive=True)
        if Path(f).is_file()
    }

    # Remove files not in source
    for target_file in target_path.iterdir():
        if target_file.is_file() and target_file.name not in source_files:
            target_file.unlink()
            print(f"  Removed (not in source): {target_file.name}")


def process_hoist_rule(rule: Dict, project_dir: Path, config_dir: Path) -> None:
    """
    Process a hoist rule.
    Moves files from target to source directory, then creates links in target.
    """
    source_path_str = rule["source"]
    target_path_str = rule["target"]
    sync_mode = rule.get("sync-mode", "symlink")

    source_path = resolve_path(source_path_str, project_dir, config_dir)
    target_path = resolve_path(target_path_str, project_dir, config_dir)

    # Ensure source directory exists
    if source_path_str.endswith("/") or "*" in source_path_str:
        # Source is a directory pattern
        source_dir = source_path.parent if "*" in source_path_str else source_path
    else:
        source_dir = source_path if source_path.is_dir() else source_path.parent
    source_dir.mkdir(parents=True, exist_ok=True)

    if not target_path.exists():
        print(f"  Skipping hoist: target not found: {target_path}")
        return

    if target_path.is_file():
        # Single file hoist
        dest_in_source = source_dir / target_path.name
        if not dest_in_source.exists():
            shutil.move(str(target_path), str(dest_in_source))
            print(f"  Hoisted: {target_path.name} -> {source_dir}")

        # Create link back
        if sync_mode == "symlink":
            try:
                rel_path = os.path.relpath(dest_in_source, target_path.parent)
                target_path.symlink_to(rel_path)
            except ValueError:
                target_path.symlink_to(dest_in_source)
            print(f"  Linked: {target_path.name} -> {dest_in_source.name}")
        else:
            shutil.copy2(dest_in_source, target_path)
            print(f"  Copied back: {dest_in_source.name} -> {target_path.name}")

    elif target_path.is_dir():
        # Directory hoist
        for target_file in target_path.iterdir():
            if not target_file.is_file():
                continue

            dest_in_source = source_dir / target_file.name
            if not dest_in_source.exists():
                shutil.move(str(target_file), str(dest_in_source))
                print(f"  Hoisted: {target_file.name} -> {source_dir}")
            else:
                target_file.unlink()

            # Create link back
            if sync_mode == "symlink":
                try:
                    rel_path = os.path.relpath(dest_in_source, target_path)
                    target_file.symlink_to(rel_path)
                except ValueError:
                    target_file.symlink_to(dest_in_source)
                print(f"  Linked: {target_file.name}")


def process_replace_rule(rule: Dict, project_dir: Path, config_dir: Path) -> None:
    """
    Process a replace rule.
    Sets file contents to the specified content.
    """
    source_path = resolve_path(rule["source"], project_dir, config_dir)
    contents = rule.get("contents", "")

    # Ensure parent directory exists
    source_path.parent.mkdir(parents=True, exist_ok=True)

    # Write the content
    with open(source_path, "w") as f:
        f.write(contents)

    print(f"  Replaced: {source_path.name}")


def process_rule(rule: Dict, project_dir: Path, config_dir: Path) -> None:
    """Process a single sync rule based on its mode"""
    mode = rule.get("mode", "sync")

    print(f"Processing rule: {rule.get('source', 'N/A')} ({mode})")

    if mode == "merge":
        process_merge_rule(rule, project_dir, config_dir)
    elif mode == "sync":
        process_sync_rule(rule, project_dir, config_dir)
    elif mode == "source-only":
        process_source_only_rule(rule, project_dir, config_dir)
    elif mode == "hoist":
        process_hoist_rule(rule, project_dir, config_dir)
    elif mode == "replace":
        process_replace_rule(rule, project_dir, config_dir)
    else:
        print(f"  Warning: Unknown mode '{mode}', skipping")


def load_config(config_path: Path) -> List[Dict]:
    """Load and parse the syncconfig.yaml file"""
    if not config_path.exists():
        return []

    with open(config_path, "r") as f:
        config = yaml.safe_load(f)

    if config is None:
        return []

    if not isinstance(config, list):
        raise SyncError(
            f"syncconfig.yaml must be a list of rules, got {type(config).__name__}"
        )

    return config


def main() -> int:
    """Main entry point for the sync hook"""
    project_dir = get_project_dir()
    config_dir = project_dir / ".claude"
    config_path = config_dir / "syncconfig.yaml"

    print(f"Sync Settings Hook - Project: {project_dir}")

    # Check if config exists
    if not config_path.exists():
        print(f"No syncconfig.yaml found at {config_path}, skipping sync")
        return 0

    try:
        # Load configuration
        rules = load_config(config_path)

        if not rules:
            print("No sync rules defined, skipping")
            return 0

        print(f"Processing {len(rules)} sync rule(s)...")

        # Process each rule in order
        for i, rule in enumerate(rules, 1):
            if not isinstance(rule, dict):
                print(f"Warning: Rule {i} is not a valid dict, skipping")
                continue

            if "source" not in rule and "mode" != "replace":
                print(f"Warning: Rule {i} missing 'source', skipping")
                continue

            process_rule(rule, project_dir, config_dir)

        print("Sync completed successfully")
        return 0

    except SyncError as e:
        print(f"Sync Error: {e}", file=sys.stderr)
        return 2
    except yaml.YAMLError as e:
        print(f"YAML Parse Error: {e}", file=sys.stderr)
        return 2
    except json.JSONDecodeError as e:
        print(f"JSON Parse Error: {e}", file=sys.stderr)
        return 2
    except Exception as e:
        print(f"Unexpected Error: {e}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
