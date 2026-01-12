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

all_scripts_in_hook_dir="$(find "$HOOK_DIR" -type f -executable | sort)"

if [ -z "$all_scripts_in_hook_dir" ]; then
    echo "Warning: No executable scripts found in $HOOK_DIR."
    exit 0
fi

EXIT_CODE=0

# run hooks sequentially
while IFS= read -r script; do
    echo "Running hook script: $script"
    # Execute the script, passing INPUT via stdin
    echo "$INPUT" | "$script" "${HOOK_ARGS[@]}"
    SCRIPT_EXIT_CODE=$?
    if [ $SCRIPT_EXIT_CODE -ne 0 ]; then
        echo "Error: Hook script $script exited with code $SCRIPT_EXIT_CODE."
        EXIT_CODE=$SCRIPT_EXIT_CODE
    fi
done <<< "$all_scripts_in_hook_dir"

echo "Finished running $HOOK_NAME" >&2
exit $EXIT_CODE
