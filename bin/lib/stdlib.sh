#!/usr/bin/env bash

# provides utilities to use in scripts around the repo.
# do not do anything functional here!

# ROOT_DIR is the root of the git repository. This is set by stdlib.sh
declare -x ROOT_DIR="${ROOT_DIR-}"

# if root_dir isn't set, try to set it
if [[ -z "${ROOT_DIR-}" ]]; then
  # DON'T DO THIS - running vscode from a terminal that already has
  # direnv initialized with this variable will result in this
  # being incorrect for other repos!
  # # if DIRENV_ROOT is set, use that
  # if [[ -n "${DIRENV_ROOT-}" ]]; then
  #   ROOT_DIR="${DIRENV_ROOT}"
  # else
  # if the script is being sourced, use the directory of the script
  if [[ -n "${BASH_SOURCE[0]}" ]]; then
    ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  else
    # if all else fails, use the git root, might fail if no .git folder
    ROOT_DIR="$(git rev-parse --show-toplevel)"
  fi
fi
export ROOT_DIR

ANSI_RED="\033[0;31m"
ANSI_GREEN="\033[0;32m"
ANSI_BLUE="\033[0;34m"
ANSI_GREY="\033[38;5;246m"
ANSI_DARK_YELLOW="\033[0;33m"
ANSI_YELLOW="\033[1;33m"
ANSI_ORANGE="\033[38;5;208m"
ANSI_PURPLE="\033[0;35m"
ANSI_RESET="\033[0m"

# if $TERM isn't set, skip this
COLUMNS=$(tput -T xterm-256color cols 2>/dev/null || echo 80)

# set debug to anything to enable debug output, defaults to unset
DEBUG=${DEBUG:-}

if_debug() {
  # if DEBUG is set to anything other than empty, run the arguments
  if [[ -n "${DEBUG}" ]]; then
    "$@"
  fi
}

error() {
  echo -e "${ANSI_RED}ERROR: $1${ANSI_RESET}" >&2
}

warn() {
  # Flush stdout before writing to stderr to maintain message ordering
  # The exec trick forces a flush of the stdout buffer
  exec 1>&1
  echo -e "${ANSI_ORANGE}$1${ANSI_RESET}" >&2
}

fatal() {
  error "$1"
  exit 1
}

hint() {
  echo -e "${ANSI_DARK_YELLOW}  hint| $1${ANSI_RESET}"
}

up_next() {
  echo -e "${ANSI_PURPLE}$1${ANSI_RESET}"
}

success() {
  echo -e "${ANSI_GREEN}$1${ANSI_RESET}"
}

debug() {
  echo -e "${ANSI_GREY}$1${ANSI_RESET}"
}

# info() prints an info message with [INFO] prefix
info() {
  echo -e "${ANSI_BLUE}[INFO]${ANSI_RESET} $1"
}


# dryrun() prints a dry-run message with [DRY] prefix
dryrun() {
  echo -e "${ANSI_YELLOW}[DRY]${ANSI_RESET} $1"
}

stream_command_as_debug() {
  while IFS= read -r line; do
    debug "$line"
  done < <("$@" 2>&1)
}

run() {
  echo -e "${ANSI_GREEN}\$ ${ANSI_GREY}$*${ANSI_RESET}"
  bash -c "$@"
}

# Map color names to terminfo setaf/setab codes.
declare -A colors
colors["black"]=0
colors["red"]=1
colors["green"]=2
colors["yellow"]=3
colors["blue"]=4
colors["magenta"]=5
colors["cyan"]=6
colors["white"]=7
# colorize colorname text
# Returns text wrapped in ANSI color tags. Unknown color names are mapped to white.
colorize() {
  printf "%s%s%s" "$(tput setaf "${colors[$1]:-7}")" "$2" "$(tput op)"
}

debounce() {
  # Usage: debounce <lockfile> <wait_time> <command>
  # Example: debounce hello 5 -- echo hello world
  local lockfile_name="$1"
  shift
  local wait_time="$1"
  shift
  # make sure the next arg is -- or exit
  if [[ "$1" != "--" ]]; then
    echo "debounce: expected -- as the next argument"
    return 1
  fi
  shift
  local lockfile="/tmp/debounce-$lockfile_name.lock"

  if [ -f "$lockfile" ]; then
    echo "debounce: $lockfile exists, skipping"
    return 1 # Already running
  else
    touch "$lockfile"
    (
      sleep "$wait_time"
      rm "$lockfile"
    ) &
    "$@"
  fi
}

yn_prompt() {
  local prompt_message="$1"
  local user_input
  read -r -p "$prompt_message [yN]: " user_input
  if [[ "$user_input" == "y" || "$user_input" == "Y" ]]; then
    return 0
  else
    return 1
  fi
}

yn_prompt_default_yes() {
  local prompt_message="$1"
  local user_input
  read -r -p "$prompt_message [Yn]: " user_input
  if [[ "$user_input" == "n" || "$user_input" == "N" ]]; then
    return 1
  else
    return 0
  fi
}

# Check for something to exist (by explicit name) and if it doesn't, try to install it from brew
# NOTE: doesn't work when the tool might be "gsed" but the package comes from "gnutils"
function check_and_install {
  local cmd="$1"
  if ! command -v "$cmd" &>/dev/null; then
    if command -v brew &>/dev/null; then
      echo "$cmd not found, installing via Homebrew..."
      if command -v gum &>/dev/null; then
        gum spin --spinner dot --title "Installing tool from brew - $cmd" -- bash -c "brew install $cmd || fatal 'Failed to install $cmd'"
      else
        (brew install "$cmd") &
        spinner "Installing tool from brew - $cmd" || fatal "Failed to install $cmd"
      fi
      echo "✅ installed $cmd"
    else
      fatal "$cmd not found and Homebrew is not installed. Exiting."
    fi
  fi
}

function spinner() {
  # usage: spinner "message" -- command args...
  # example: spinner "Waiting for something to finish" -- sleep 5
  local message="$1"
  shift
  # make sure the next arg is -- or exit
  if [[ "$1" != "--" ]]; then
    echo "spinner: expected -- as the next argument"
    return 1
  fi
  shift
  check_and_install gum
  gum spin --spinner dot --title "$message" -- "$@"
}

# spinner() {
#   # usage:
#   #   (a_long_running_task) 1> /dev/null &
#   #   spinner "Waiting for a long running task to finish" || fatal "The long running task failed"
#   local message="$1"
#   local pid=$!
#   local start_time="$(date +%s)"
#   local delay=0.2
#   # shellcheck disable=SC1003 # Why: Not escaping a squote.
#   local spinstr='|/-\'
#   if [[ -t 0 ]]; then
#     # if the terminal is interactive we can display the spinner
#     while kill -0 $pid 2>/dev/null; do
#       local temp=${spinstr#?}
#       # clear the line and move back to the beginning
#       printf "\r%-${COLUMNS}s\r" " "
#       printf "\r [%c] %s\r" "$spinstr" "$message"
#       local spinstr=$temp${spinstr%"$temp"}
#       sleep $delay
#     done
#   else
#     # if the terminal is not interactive, just print the message without the spinner
#     echo "$message"
#   fi

#   wait $pid
#   local exit_code=$?
#   # clear the line if the terminal is interactive
#   [[ -t 0 ]] && printf "\r%-${COLUMNS}s\r" " "
#   local end_time="$(date +%s)"
#   local seconds=$((end_time - start_time))
#   # reprint the message without the spinner but with the time it took
#   echo -e "$message" "${ANSI_GREY}($seconds seconds)${ANSI_RESET}"
#   if [[ $exit_code -ne 0 ]]; then
#     error "Task failed (exit code: $exit_code)"
#   fi
#   return $exit_code
# }

# Retry retries the command with exponential backoff, giving up after a
# certain amount of attempts.
#
# Usage: retry <max_attempts> <initial_delay_ms> <command> [args...]
retry() {
  local max_attempts="$1"
  shift
  local delay_ms="$1"
  shift
  local attempt=1

  until "$@"; do
    if ((attempt >= max_attempts)); then
      error "'$*': failed after $attempt attempts."
      return 1
    fi
    warn "Attempt $attempt failed. Retrying in $delay_ms ms..."
    sleep "$(awk "BEGIN { print $delay_ms/1000 }")"
    delay_ms=$((delay_ms * 2))
    attempt=$((attempt + 1))
  done
}

# Usage: expand_path <rel_path> [<relative_to>]
#
# Outputs the absolute path of <rel_path> relative to <relative_to> or the
# current directory.
#
# Example:
#
#    cd /usr/local/games
#    expand_path ../foo
#    # output: /usr/local/foo
#
expand_path() {
  local REPLY
  realpath.absolute "${2+"$2"}" "${1+"$1"}"
  echo "$REPLY"
}

# --- vendored from https://github.com/bashup/realpaths
realpath.dirname() {
  REPLY=.
  ! [[ $1 =~ /+[^/]+/*$|^//$ ]] || REPLY="${1%"${BASH_REMATCH[0]}"}"
  REPLY=${REPLY:-/}
}
realpath.basename() {
  REPLY=/
  ! [[ $1 =~ /*([^/]+)/*$ ]] || REPLY="${BASH_REMATCH[1]}"
}

realpath.absolute() {
  REPLY=$PWD
  local eg=extglob
  ! shopt -q $eg || eg=
  ${eg:+shopt -s $eg}
  while (($#)); do case $1 in
    // | //[^/]*)
      REPLY=//
      set -- "${1:2}" "${@:2}"
      ;;
    /*)
      REPLY=/
      set -- "${1##+(/)}" "${@:2}"
      ;;
    */*) set -- "${1%%/*}" "${1##"${1%%/*}"+(/)}" "${@:2}" ;;
    '' | .) shift ;;
    ..)
      realpath.dirname "$REPLY"
      shift
      ;;
    *)
      REPLY="${REPLY%/}/$1"
      shift
      ;;
    esac done
  ${eg:+shopt -u $eg}
}
# ---

# Usage: find_up <filename>
#
# Outputs the path of <filename> when searched from the current directory up to
# /. Returns 1 if the file has not been found.
#
# Example:
#
#    cd /usr/local/my
#    mkdir -p project/foo
#    touch bar
#    cd project/foo
#    find_up bar
#    # output: /usr/local/my/bar
#
find_up() {
  (
    while true; do
      # if it is a file, return it
      if [[ -f $1 ]]; then
        echo "$PWD/$1"
        return 0
      fi
      # if it is a directory, return it
      if [[ -d $1 ]]; then
        echo "$PWD/$1"
        return 0
      fi
      # if we are at the root, return failure
      if [[ $PWD == / ]] || [[ $PWD == // ]]; then
        return 1
      fi
      cd ..
    done
  )
}

# find_files returns a newline separated list of files as they appear in
# the git index.
#
# Instead of searching the file system directly, we query the index
# to instead ensure we only get files that are tracked by Git. As part
# of this, we also have to manually remove deleted files.
#
# Usage: find_files [paths]
find_files() {
  files="$(git ls-files --cached --others --modified --exclude-standard "$@" |
    # Remove duplicates.
    sort | uniq |
    # Remove deleted files from the list.
    grep -vE "^$(git ls-files --deleted | paste -sd "|" -)$")"
  while read -r file; do
    # by default, git ls-files returns relative paths, so we need to
    # convert them to absolute paths so when we use these file locations
    # they're always the same regardless of the current working directory.
    # This is especially important when we're hashing them for detecting
    # actionable changes.
    # Do it in a loop like this because expand_path is a shell function
    # and xargs doesn't support shell functions.
    expand_path "$file"
  done <<<"$files"
}

# find_files_with_extensions returns a newline separated list of files
# that contain one of the provided extensions.
#
# Usage: find_files_with_extensions <extensions...>
find_files_with_extensions() {
  local extensions=("$@")

  # Git expects a slightly different format, so we map that here.
  local git_exts=()
  for ext in "${extensions[@]}"; do
    git_exts+=("*.$ext")
  done

  find_files "${git_exts[@]}"
}

# required ensures the following tools are installed, if they aren't
# then a helpful message is displayed and exit code 2 is returned.
required() {
  missing=()
  for cmd in "$@"; do
    if ! command -v "$cmd" &>/dev/null; then
      missing+=("$cmd")
    fi
  done

  if [[ ${#missing[@]} -eq 0 ]]; then
    return
  fi

  error "Missing the following tools: ${missing[*]}"
  echo "Hint: Install them through the following command:"
  echo "   brew bundle install"

  return 2
}

# Function to sync a directory pair
sync_directory() {
  local SOURCE_DIR="$1"
  local DEST_DIR="$2"

  # Only sync if source directory exists and has files
  if [[ -d "$SOURCE_DIR" ]] && [[ -n "$(ls -A "$SOURCE_DIR" 2>/dev/null)" ]]; then
    # Create destination if it doesn't exist
    mkdir -p "$DEST_DIR"

    # Use rsync to sync, excluding .gitkeep and .gitignore
    if command -v rsync >/dev/null 2>&1; then
      # Rsync is included on macos
      rsync -a --delete \
        --exclude='.gitkeep' \
        --exclude='.gitignore' \
        "$SOURCE_DIR/" "$DEST_DIR/" 2>/dev/null
    else
      fatal "rsync command not found, cannot sync $SOURCE_DIR to $DEST_DIR"
    fi
  fi
}

# Create directory symlink, handling dry-run mode and existing links
#
# Dependencies (variables expected to be set by caller):
#   - DRY_RUN: boolean (true/false) - if true, only shows what would be done
#
# Usage: create_dir_symlink <source> <target>
create_dir_symlink() {
  local source="$1"
  local target="$2"

  # Check if symlink already exists
  if [[ -L "$target" ]]; then
    local existing_target
    existing_target=$(readlink "$target")
    if [[ "$existing_target" == "$source" ]]; then
      return 0
    else
      error "Symlink exists but points to different target!"
      error "  Expected: $source"
      error "  Actual:   $existing_target"
      error "  Remove the symlink manually or fix the conflict."
      exit 1
    fi
  elif [[ -e "$target" ]]; then
    error "Target exists and is not a symlink: $target"
    error "  Remove it manually if you want to sync here."
    exit 1
  fi

  if [[ "${DRY_RUN:-true}" == true ]]; then
    dryrun "Would create: $target -> $source"
    return 0
  fi

  # Create parent directory if needed
  local parent_dir
  parent_dir=$(dirname "$target")
  mkdir -p "$parent_dir"

  # Create the symlink
  ln -s "$source" "$target"
  success "Created: $target -> $source"
}
