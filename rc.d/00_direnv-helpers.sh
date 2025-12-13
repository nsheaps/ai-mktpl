#!/usr/bin/env bash

# shellcheck source=../bin/lib/stdlib.sh
source "${DIRENV_ROOT}/bin/lib/stdlib.sh"

export DIRENV_OPTIONS="${DIRENV_ROOT}/.envrc.options"

# don't warn if direnv is taking < 3 minutes. In most cases it should < 1s, but there may be
# some cases where direnv runs something interactive and can take longer (like yarn install)
export DIRENV_WARN_TIMEOUT=3m

# if direnv options exists, source it
# we have to do it this way because direnv loading actually occurs in the background
# and direnv works by checking the state of the environment before and after running the
# .envrc file. If we just run direnv reload, it will:
# a) ignore the runtime variable because the process is running in the context
#    of the current shell, not the call to `direnv reload`
# b) move onto the next command to unset it before direnv even starts reloading
# This way, we can set the variable in the environment, then reload direnv, and it will
# clean up the temporary options in the last rc.d script it runs (99_remove-direnv-options.sh)
if [[ -f "${DIRENV_OPTIONS}" ]]; then
  if_debug echo "Loading direnv options"
  # shellcheck disable=SC1090 # Not a static file.
  source "${DIRENV_OPTIONS}"
fi

# Dev note: this only affects logs from direnv, any echo lines from within the scripts it's loading will still print.
export DIRENV_LOG_FORMAT=''
# make it faint and grey if debugging
if_debug export DIRENV_LOG_FORMAT=$'\033[2mdirenv: %s\033[0m'

# PATCH FOR BUG: https://github.com/direnv/direnv/issues/1227
# MANPATH must be defined, else direnv might run `man -w` which on some platforms may return "Which manual page do you want?"
if [[ -z "${MANPATH:-}" ]]; then
  if command -v manpath &>/dev/null; then
    export MANPATH="$(manpath)"
  else
    export MANPATH=""
  fi
fi

# watch rc.d for changes so direnv can reload
watch_dir "${DIRENV_ROOT}/rc.d"

# watch for changing branches to re-run direnv since direnv handles branch-change cleanup
watch_file "${DIRENV_ROOT}/.git/HEAD"

# dump the direnv stdlib to a file to make it easier to look for functionality, though the
# file remains unused
direnv stdlib >"${DIRENV_ROOT}/bin/lib/direnv.stdlib.sh"
