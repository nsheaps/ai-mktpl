#!/bin/bash
# Symlink claude-tools plugin binaries to user's PATH
# This hook runs at session start to make the plugin's binaries available globally

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
  success "claude-tools: Symlinked $SYMLINKS_CREATED binary(ies) to $TARGET"
else
  info "claude-tools: No binaries found to symlink"
fi

exit 0
