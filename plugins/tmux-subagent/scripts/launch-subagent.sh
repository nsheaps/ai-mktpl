#!/usr/bin/env bash
# launch-subagent.sh - Launch a Claude sub-agent in a tmux session
#
# This script creates an isolated workspace for a sub-agent with custom
# configurations while allowing it to operate on the original project.
#
# Usage: launch-subagent.sh [OPTIONS]
#
# Options:
#   --name NAME           Session name (default: subagent-<timestamp>)
#   --work-dir DIR        Directory for the agent to work in (default: current)
#   --prompt PROMPT       Initial prompt for the agent
#   --prompt-file FILE    File containing the initial prompt
#   --allowed-tools TOOLS Comma-separated list of allowed tools
#   --denied-tools TOOLS  Comma-separated list of denied tools
#   --plugins PLUGINS     Comma-separated list of plugin paths to install
#   --permission-mode MODE Permission mode: allowedTools, dontAsk (default: allowedTools)
#   --model MODEL         Model to use (default: inherits from parent)
#   --no-iterm            Don't open iTerm tab
#   --attach              Attach to session after creation (blocks)
#   --config FILE         JSON config file with all options
#   --help                Show this help message

set -euo pipefail

# Script directory (for accessing other plugin scripts)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(dirname "$SCRIPT_DIR")"

# Defaults
SESSION_NAME=""
WORK_DIR="${PWD}"
INITIAL_PROMPT=""
PROMPT_FILE=""
ALLOWED_TOOLS=""
DENIED_TOOLS=""
PLUGINS=""
PERMISSION_MODE="allowedTools"
MODEL=""
OPEN_ITERM="true"
ATTACH_SESSION="false"
CONFIG_FILE=""

# Color output helpers
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

show_help() {
    head -22 "$0" | tail -21 | sed 's/^# //' | sed 's/^#//'
    exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --name) SESSION_NAME="$2"; shift 2 ;;
        --work-dir) WORK_DIR="$2"; shift 2 ;;
        --prompt) INITIAL_PROMPT="$2"; shift 2 ;;
        --prompt-file) PROMPT_FILE="$2"; shift 2 ;;
        --allowed-tools) ALLOWED_TOOLS="$2"; shift 2 ;;
        --denied-tools) DENIED_TOOLS="$2"; shift 2 ;;
        --plugins) PLUGINS="$2"; shift 2 ;;
        --permission-mode) PERMISSION_MODE="$2"; shift 2 ;;
        --model) MODEL="$2"; shift 2 ;;
        --no-iterm) OPEN_ITERM="false"; shift ;;
        --attach) ATTACH_SESSION="true"; shift ;;
        --config) CONFIG_FILE="$2"; shift 2 ;;
        --help|-h) show_help ;;
        *) log_error "Unknown option: $1"; exit 1 ;;
    esac
done

# Load config file if provided
if [[ -n "$CONFIG_FILE" && -f "$CONFIG_FILE" ]]; then
    log_info "Loading config from $CONFIG_FILE"
    if command -v jq &>/dev/null; then
        SESSION_NAME="${SESSION_NAME:-$(jq -r '.name // empty' "$CONFIG_FILE")}"
        WORK_DIR="${WORK_DIR:-$(jq -r '.workDir // empty' "$CONFIG_FILE")}"
        INITIAL_PROMPT="${INITIAL_PROMPT:-$(jq -r '.prompt // empty' "$CONFIG_FILE")}"
        PROMPT_FILE="${PROMPT_FILE:-$(jq -r '.promptFile // empty' "$CONFIG_FILE")}"
        ALLOWED_TOOLS="${ALLOWED_TOOLS:-$(jq -r '.allowedTools // empty' "$CONFIG_FILE")}"
        DENIED_TOOLS="${DENIED_TOOLS:-$(jq -r '.deniedTools // empty' "$CONFIG_FILE")}"
        PLUGINS="${PLUGINS:-$(jq -r '.plugins // empty' "$CONFIG_FILE")}"
        PERMISSION_MODE="${PERMISSION_MODE:-$(jq -r '.permissionMode // empty' "$CONFIG_FILE")}"
        MODEL="${MODEL:-$(jq -r '.model // empty' "$CONFIG_FILE")}"
    else
        log_warn "jq not found, cannot parse config file"
    fi
fi

# Generate session name if not provided
if [[ -z "$SESSION_NAME" ]]; then
    SESSION_NAME="subagent-$(date +%s)"
fi

# Sanitize session name for tmux (no dots or colons)
SESSION_NAME=$(echo "$SESSION_NAME" | tr './:' '-')

# Resolve work directory to absolute path
WORK_DIR="$(cd "$WORK_DIR" 2>/dev/null && pwd)" || {
    log_error "Work directory does not exist: $WORK_DIR"
    exit 1
}

# Load prompt from file if specified
if [[ -n "$PROMPT_FILE" && -f "$PROMPT_FILE" ]]; then
    INITIAL_PROMPT="$(cat "$PROMPT_FILE")"
fi

log_info "Creating sub-agent workspace..."
log_info "  Session: $SESSION_NAME"
log_info "  Work dir: $WORK_DIR"

# Create temporary workspace
WORKSPACE_DIR="/tmp/claude-subagent/${SESSION_NAME}"
mkdir -p "$WORKSPACE_DIR/.claude"

log_info "  Workspace: $WORKSPACE_DIR"

# Copy parent project's .claude config if it exists
if [[ -d "$WORK_DIR/.claude" ]]; then
    log_info "Copying parent project configuration..."
    cp -r "$WORK_DIR/.claude/." "$WORKSPACE_DIR/.claude/" 2>/dev/null || true
fi

# Create settings.json with allowed directories
SETTINGS_FILE="$WORKSPACE_DIR/.claude/settings.json"
SETTINGS_LOCAL_FILE="$WORKSPACE_DIR/.claude/settings.local.json"

# Start with existing settings or empty object
if [[ -f "$SETTINGS_FILE" ]]; then
    EXISTING_SETTINGS=$(cat "$SETTINGS_FILE")
else
    EXISTING_SETTINGS='{}'
fi

# Build the new settings with jq
# Claude Code permissions format uses flat arrays:
# { "permissions": { "allow": ["Tool", "Tool(pattern)"], "deny": ["Tool"] } }
if command -v jq &>/dev/null; then
    # Add directory access permissions for the work directory
    # Format: Read(/path/**), Write(/path/**), Edit(/path/**)
    EXISTING_SETTINGS=$(echo "$EXISTING_SETTINGS" | jq --arg dir "$WORK_DIR" '
        .permissions.allow = ((.permissions.allow // []) + [
            "Read(\($dir)/**)",
            "Write(\($dir)/**)",
            "Edit(\($dir)/**)"
        ] | unique)
    ')

    # Add allowed tools if specified
    if [[ -n "$ALLOWED_TOOLS" ]]; then
        IFS=',' read -ra TOOLS <<< "$ALLOWED_TOOLS"
        for tool in "${TOOLS[@]}"; do
            tool=$(echo "$tool" | xargs) # trim whitespace
            EXISTING_SETTINGS=$(echo "$EXISTING_SETTINGS" | jq --arg tool "$tool" '
                .permissions.allow = ((.permissions.allow // []) + [$tool] | unique)
            ')
        done
    fi

    # Add denied tools if specified
    if [[ -n "$DENIED_TOOLS" ]]; then
        IFS=',' read -ra TOOLS <<< "$DENIED_TOOLS"
        for tool in "${TOOLS[@]}"; do
            tool=$(echo "$tool" | xargs) # trim whitespace
            EXISTING_SETTINGS=$(echo "$EXISTING_SETTINGS" | jq --arg tool "$tool" '
                .permissions.deny = ((.permissions.deny // []) + [$tool] | unique)
            ')
        done
    fi

    echo "$EXISTING_SETTINGS" > "$SETTINGS_FILE"
else
    log_warn "jq not found, creating minimal settings"
    cat > "$SETTINGS_FILE" << EOF
{
  "permissions": {
    "allow": [
      "Read($WORK_DIR/**)",
      "Write($WORK_DIR/**)",
      "Edit($WORK_DIR/**)"
    ]
  }
}
EOF
fi

# Create a local settings file with session-specific info
cat > "$SETTINGS_LOCAL_FILE" << EOF
{
  "_comment": "Auto-generated by tmux-subagent plugin",
  "_session": "$SESSION_NAME",
  "_workDir": "$WORK_DIR",
  "_created": "$(date -Iseconds)"
}
EOF

# Install additional plugins if specified
if [[ -n "$PLUGINS" ]]; then
    log_info "Installing additional plugins..."
    IFS=',' read -ra PLUGIN_LIST <<< "$PLUGINS"
    for plugin_path in "${PLUGIN_LIST[@]}"; do
        plugin_path=$(echo "$plugin_path" | xargs) # trim whitespace
        if [[ -d "$plugin_path" ]]; then
            plugin_name=$(basename "$plugin_path")
            log_info "  Installing plugin: $plugin_name"
            # Create symlink to plugin in workspace
            mkdir -p "$WORKSPACE_DIR/.claude/plugins"
            ln -sf "$plugin_path" "$WORKSPACE_DIR/.claude/plugins/$plugin_name"
        else
            log_warn "  Plugin not found: $plugin_path"
        fi
    done
fi

# Create CLAUDE.md with instructions for the sub-agent
cat > "$WORKSPACE_DIR/.claude/CLAUDE.md" << EOF
# Sub-Agent Workspace

This is a temporary workspace for a Claude sub-agent session.

**IMPORTANT**: Your primary work directory is: \`$WORK_DIR\`

All file operations should be performed in that directory unless otherwise specified.
This workspace directory ($WORKSPACE_DIR) is for configuration only.

## Session Info
- Session Name: $SESSION_NAME
- Created: $(date)
- Parent Work Dir: $WORK_DIR

## Instructions
When making changes, always operate on files in: $WORK_DIR
Do NOT create or modify files in this temporary workspace except for scratch/notes.

EOF

# Build the claude command
CLAUDE_CMD="claude"

# Add permission mode
case "$PERMISSION_MODE" in
    dontAsk|dangerously-skip-permissions)
        CLAUDE_CMD="$CLAUDE_CMD --dangerously-skip-permissions"
        ;;
    allowedTools|*)
        # Default: use allowedTools mode (prompts for unrecognized)
        CLAUDE_CMD="$CLAUDE_CMD --allowedTools 'Edit(**)' --allowedTools 'Write(**)' --allowedTools 'Read(**)' --allowedTools 'Bash(*)' --allowedTools 'Glob' --allowedTools 'Grep'"
        ;;
esac

# Add model if specified
if [[ -n "$MODEL" ]]; then
    CLAUDE_CMD="$CLAUDE_CMD --model $MODEL"
fi

# Store initial prompt separately - we'll send it after Claude starts
# This keeps Claude in interactive mode instead of exiting after the task
SEND_INITIAL_PROMPT="$INITIAL_PROMPT"

# Check if tmux is installed
if ! command -v tmux &>/dev/null; then
    log_error "tmux is not installed. Please install it first."
    exit 1
fi

# Check if session already exists
if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    log_warn "Session $SESSION_NAME already exists"
    echo "$SESSION_NAME"
    exit 0
fi

# Create the tmux session
log_info "Creating tmux session: $SESSION_NAME"

# Create a wrapper script for clean execution
# This avoids quoting issues with nested commands
WRAPPER_SCRIPT="$WORKSPACE_DIR/run-agent.sh"
cat > "$WRAPPER_SCRIPT" << 'WRAPPER_EOF'
#!/usr/bin/env bash
# Auto-generated wrapper script for tmux-subagent
export CLAUDE_SUBAGENT_SESSION='SESSION_NAME_PLACEHOLDER'
export CLAUDE_SUBAGENT_WORKSPACE='WORKSPACE_PLACEHOLDER'

cd 'WORK_DIR_PLACEHOLDER' || exit 1

# Run claude in interactive mode
CLAUDE_COMMAND_PLACEHOLDER

# Claude exited - show resume information
EXIT_CODE=$?
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Sub-agent exited with code: $EXIT_CODE"
echo ""
echo "To resume this session:"
echo "  claude --resume"
echo ""
echo "Or start fresh in this directory:"
echo "  claude"
echo ""
echo "Session workspace: WORKSPACE_PLACEHOLDER"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Shell ready. Type 'exit' to close this tab."

# Keep shell open - don't exit the iTerm tab
exec bash --norc --noprofile
WRAPPER_EOF

# Replace placeholders with actual values (avoids quoting issues)
sed -i '' "s|SESSION_NAME_PLACEHOLDER|$SESSION_NAME|g" "$WRAPPER_SCRIPT"
sed -i '' "s|WORKSPACE_PLACEHOLDER|$WORKSPACE_DIR|g" "$WRAPPER_SCRIPT"
sed -i '' "s|WORK_DIR_PLACEHOLDER|$WORK_DIR|g" "$WRAPPER_SCRIPT"
sed -i '' "s|CLAUDE_COMMAND_PLACEHOLDER|$CLAUDE_CMD|g" "$WRAPPER_SCRIPT"
chmod +x "$WRAPPER_SCRIPT"

# Create session with wrapper script (proper TTY allocation, clean output)
tmux new-session -d -s "$SESSION_NAME" -c "$WORK_DIR" "$WRAPPER_SCRIPT"

# Wait for Claude to start, then send the initial prompt if provided
if [[ -n "$SEND_INITIAL_PROMPT" ]]; then
    # Give Claude time to initialize
    sleep 2
    # Send the prompt (this keeps Claude interactive unlike -p flag)
    tmux send-keys -t "$SESSION_NAME" "$SEND_INITIAL_PROMPT" Enter
fi

log_success "Sub-agent session created: $SESSION_NAME"

# Open iTerm tab if requested and on macOS
if [[ "$OPEN_ITERM" == "true" && "$(uname)" == "Darwin" ]]; then
    APPLESCRIPT="$SCRIPT_DIR/attach-iterm.applescript"
    if [[ -f "$APPLESCRIPT" ]]; then
        log_info "Opening iTerm tab attached to session..."
        osascript "$APPLESCRIPT" "$SESSION_NAME" 2>/dev/null || {
            log_warn "Could not open iTerm tab. You can manually attach with:"
            log_warn "  tmux attach -t $SESSION_NAME"
        }
    else
        log_warn "iTerm AppleScript not found at: $APPLESCRIPT"
    fi
fi

# Attach if requested (blocks until session ends)
if [[ "$ATTACH_SESSION" == "true" ]]; then
    log_info "Attaching to session (press Ctrl-B D to detach)..."
    tmux attach -t "$SESSION_NAME"
else
    echo ""
    log_info "To monitor the session:"
    echo "  tmux attach -t $SESSION_NAME        # Attach interactively"
    echo "  tmux capture-pane -t $SESSION_NAME -p  # View current output"
    echo "  tmux send-keys -t $SESSION_NAME 'your message' Enter  # Send input"
    echo ""
fi

# Output session name for programmatic use
echo "$SESSION_NAME"
