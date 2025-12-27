#!/usr/bin/env bash

set -euo pipefail

# ensure root_dir is set
: "${ROOT_DIR:?Environment variable ROOT_DIR must be set}"
# shellcheck source=./bin/lib/stdlib.sh
source "${ROOT_DIR}"/bin/lib/stdlib.sh

cd "${ROOT_DIR}"

# activate mise environment
# check to see that mise is installed.
if command -v mise &> /dev/null; then

    # if not installed via a package manager, having an out of date
    # version of mise can result in strange errors when installing node due to gpg
    # signing, so we'll just eat the error
    mise self-update >/dev/null 2>&1 || true
    # TODO: if claude or CI, run as verbose
    mise trust
    mise install -y

    # if mise's default resolution is a function, then mise is already activated.
    eval "$(mise activate bash)"
else
    # mise is not installed, error and exit
    # TODO: try and re-use this logic with the SessionStart hook
    echo "Error: mise is not installed. Please install mise to proceed."
    echo "   see : https://mise.jdx.dev/cli/install.html"
    exit 1
fi

