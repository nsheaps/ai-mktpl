#!/usr/bin/env bash

# these are special functions that are only available during the context
# of direnv execution thanks to https://github.com/direnv/direnv/blob/master/stdlib.sh
env_vars_required DIRENV_OPTIONS

rm -f "${DIRENV_OPTIONS}"
