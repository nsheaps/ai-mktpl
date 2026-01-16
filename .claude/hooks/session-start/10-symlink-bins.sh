#!/bin/bash
# Symlink plugin binaries to user's PATH
# This hook runs at session start to make plugin binaries available globally

set -e

info() {
  echo "ℹ️  $*"
}

success() {
  echo "✅ $*"
}

warn() {
  echo "⚠️  $*"
}

# Find target directory for symlinks
# Priority: $CLAUDE_PROJECT_DIR/bin (if in PATH) > ~/.local/bin (if in PATH)
find_target_dir() {
  if [[ -n "$CLAUDE_PROJECT_DIR" ]] && [[ ":$PATH:" == *":$CLAUDE_PROJECT_DIR/bin:"* ]]; then
    echo "$CLAUDE_PROJECT_DIR/bin"
  elif [[ ":$PATH:" == *":$HOME/.local/bin:"* ]]; then
    echo "$HOME/.local/bin"
  fi
}

TARGET=$(find_target_dir)
if [[ -z "$TARGET" ]]; then
  warn "Neither \$CLAUDE_PROJECT_DIR/bin nor ~/.local/bin in PATH"
  info "Plugin binaries will not be available globally"
  info "Add one of these directories to your PATH to enable plugin binaries"
  exit 0
fi

# Ensure target directory exists
mkdir -p "$TARGET"

# Find plugin directories - check multiple locations
PLUGIN_DIRS=()

# User-level plugins
if [[ -d "$HOME/.claude/plugins" ]]; then
  PLUGIN_DIRS+=("$HOME/.claude/plugins")
fi

# Project-level plugins
if [[ -n "$CLAUDE_PROJECT_DIR" ]] && [[ -d "$CLAUDE_PROJECT_DIR/plugins" ]]; then
  PLUGIN_DIRS+=("$CLAUDE_PROJECT_DIR/plugins")
fi

if [[ ${#PLUGIN_DIRS[@]} -eq 0 ]]; then
  info "No plugin directories found"
  exit 0
fi

# Track symlinks created
SYMLINKS_CREATED=0

# Find and symlink plugin binaries
for plugin_dir in "${PLUGIN_DIRS[@]}"; do
  for plugin in "$plugin_dir"/*/; do
    plugin_bin_dir="${plugin}bin"
    if [[ -d "$plugin_bin_dir" ]]; then
      for binary in "$plugin_bin_dir"/*; do
        if [[ -x "$binary" ]] && [[ -f "$binary" ]]; then
          name=$(basename "$binary")
          ln -sf "$binary" "$TARGET/$name"
          ((SYMLINKS_CREATED++))
        fi
      done
    fi
  done
done

if [[ $SYMLINKS_CREATED -gt 0 ]]; then
  success "Symlinked $SYMLINKS_CREATED plugin binary(ies) to $TARGET"
else
  info "No plugin binaries found to symlink"
fi

exit 0
