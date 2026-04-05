#!/usr/bin/env bash

# Usage: ./run-hook.sh <hook-name>
# Example: ./run-hook.sh pre-commit
# Takes the hook info passed as stdin from claude to this script,
# and executes all the hooks in the corresponding .claude/hooks/<hook-name>/ directory.
# If run without args prints usage info and exits 1
# supports the -h/--help flags to print usage info and exit 0
# It supports both TTY and non-TTY input. Claude executing the script will pass
# the hook info via stdin, while a user running the script directly _can_ via piping
# but can also choose to run it without providing input.
# If this script is called with additional arguments, they can be passed to the hook scripts
# like so:
#    claude-hook-call | ./run-hook.sh <hook-name> <additional-args>...
# Avoid doing this as the info is generally available from claude in the input, but this can be
# useful for testing hooks.
#
# If the directory for the hooks (by slug) is empty, it exits successfully, but prints a warning.
# If it's not, we read from it, otherwise we set INPUT to an empty string.
# If it is, we set INPUT to an empty string.
#
# The script also sets the HOOK_NAME variable to the name of the hook being run.

IS_TTY=$( [ -t 0 ] && echo "true" || echo "false" )
if [ "$IS_TTY" = "true" ]; then
    INPUT=""
else
    INPUT="$(cat)"
fi
HOOK_NAME=""
if [[ $# -eq 0 ]]; then
    echo "Usage: $0 <hook-name>"
    echo "Example: $0 pre-commit"
    exit 1
elif [[ $1 == "-h" || $1 == "--help" ]]; then
    echo "Usage: $0 <hook-name>"
    echo "Example: $0 pre-commit"
    exit 0
else
    # Theres at least one arg
    # the first arg is always the hook name
    # Anything after is passed to the hook scripts as additional args
    HOOK_NAME="$1"
    shift
fi

HOOK_ARGS=("$@")

HOOK_DIR=".claude/hooks/$HOOK_NAME"
export HOOK_NAME
export HOOK_DIR
export HOOK_ARGS
export INPUT

# Check if hook directory exists
if [ ! -d "$HOOK_DIR" ]; then
    echo "Warning: Hook directory $HOOK_DIR does not exist."
    exit 0
fi

# Find all shell scripts in the hook directory (portable approach)
# Use glob instead of find for better cross-platform compatibility
shopt -s nullglob
all_scripts=("$HOOK_DIR"/*.sh)
shopt -u nullglob

if [ ${#all_scripts[@]} -eq 0 ]; then
    echo "Warning: No shell scripts found in $HOOK_DIR."
    exit 0
fi

# Ensure all scripts are executable
for script in "${all_scripts[@]}"; do
    if [ ! -x "$script" ]; then
        echo "Making $script executable..."
        chmod +x "$script"
    fi
done

# Sort scripts by name for consistent execution order
IFS=$'\n' sorted_scripts=($(printf '%s\n' "${all_scripts[@]}" | sort))
unset IFS

EXIT_CODE=0

# Run hooks sequentially
for script in "${sorted_scripts[@]}"; do
    echo "Running hook script: $script"
    # Execute the script, passing INPUT via stdin
    echo "$INPUT" | "$script" "${HOOK_ARGS[@]}"
    SCRIPT_EXIT_CODE=$?
    if [ $SCRIPT_EXIT_CODE -ne 0 ]; then
        echo "Error: Hook script $script exited with code $SCRIPT_EXIT_CODE."
        EXIT_CODE=$SCRIPT_EXIT_CODE
    fi
done

echo "Finished running $HOOK_NAME" >&2
exit $EXIT_CODE
