#!/bin/bash
# Symlink claude-tools plugin binaries to user's PATH
# This hook runs at session start to make the plugin's binaries available globally

set -e

PLUGIN_NAME="claude-tools"

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
# Priority: ~/.local/bin (if in PATH) > $CLAUDE_PROJECT_DIR/bin (if in PATH)
find_target_dir() {
  if [[ ":$PATH:" == *":$HOME/.local/bin:"* ]]; then
    echo "$HOME/.local/bin"
  elif [[ -n "$CLAUDE_PROJECT_DIR" ]] && [[ ":$PATH:" == *":$CLAUDE_PROJECT_DIR/bin:"* ]]; then
    echo "$CLAUDE_PROJECT_DIR/bin"
  fi
}

# Clean up existing symlinks from this plugin in a directory
# Matches symlinks that point to any path containing the plugin name
cleanup_old_symlinks() {
  local dir="$1"
  local cleaned=0

  if [[ ! -d "$dir" ]]; then
    return 0
  fi

  for link in "$dir"/*; do
    if [[ -L "$link" ]]; then
      local target
      target=$(readlink "$link" 2>/dev/null || true)
      # Check if symlink points to a path containing our plugin name
      if [[ "$target" == *"/$PLUGIN_NAME/"* ]]; then
        rm -f "$link"
        ((cleaned++))
      fi
    fi
  done

  if [[ $cleaned -gt 0 ]]; then
    info "$PLUGIN_NAME: Cleaned up $cleaned old symlink(s) from $dir"
  fi
}

TARGET=$(find_target_dir)
if [[ -z "$TARGET" ]]; then
  warn "Neither ~/.local/bin nor \$CLAUDE_PROJECT_DIR/bin in PATH"
  info "Plugin binaries will not be available globally"
  info "Add one of these directories to your PATH to enable plugin binaries"
  exit 0
fi

# Ensure target directory exists
mkdir -p "$TARGET"

# Clean up old symlinks from this plugin (from previous versions or hook runs)
# Check both potential target directories
cleanup_old_symlinks "$HOME/.local/bin"
if [[ -n "$CLAUDE_PROJECT_DIR" ]]; then
  cleanup_old_symlinks "$CLAUDE_PROJECT_DIR/bin"
fi

# Use CLAUDE_PLUGIN_ROOT to find our binaries
PLUGIN_BIN="${CLAUDE_PLUGIN_ROOT}/bin"

if [[ ! -d "$PLUGIN_BIN" ]]; then
  info "No bin directory found in plugin"
  exit 0
fi

# Track symlinks created
SYMLINKS_CREATED=0

# Symlink our binaries
for binary in "$PLUGIN_BIN"/*; do
  if [[ -x "$binary" ]] && [[ -f "$binary" ]]; then
    name=$(basename "$binary")
    ln -sf "$binary" "$TARGET/$name"
    ((SYMLINKS_CREATED++))
  fi
done

if [[ $SYMLINKS_CREATED -gt 0 ]]; then
  success "$PLUGIN_NAME: Symlinked $SYMLINKS_CREATED binary(ies) to $TARGET"
else
  info "$PLUGIN_NAME: No binaries found to symlink"
fi

exit 0
