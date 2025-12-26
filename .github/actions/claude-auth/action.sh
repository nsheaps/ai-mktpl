#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
log_info() {
    echo -e "${GREEN}[Claude Auth]${NC} $1"
}

log_error() {
    echo -e "${RED}[Claude Auth Error]${NC} $1" >&2
}

log_warning() {
    echo -e "${YELLOW}[Claude Auth Warning]${NC} $1"
}

# Function to mask sensitive data
mask_value() {
    local value="$1"
    echo "::add-mask::$value"
}

# Function to set GitHub output
set_output() {
    local name="$1"
    local value="$2"
    echo "$name=$value" >> "$GITHUB_OUTPUT"
}

# Function to export environment variable
export_env_var() {
    local name="$1"
    local value="$2"
    echo "$name=$value" >> "$GITHUB_ENV"
    log_info "Exported $name to environment"
}

# Main authentication logic
authenticate() {
    local provider="${INPUT_PROVIDER:-raw}"
    local api_key=""

    log_info "Using provider: $provider"

    case "$provider" in
        raw)
            log_info "Using raw secret provider"

            if [ -z "$INPUT_API_KEY" ]; then
                log_error "api-key input is required when using raw provider"
                exit 1
            fi

            api_key="$INPUT_API_KEY"
            log_info "API key loaded from raw input"
            ;;

        doppler)
            log_info "Using Doppler secret provider"

            if [ -z "$INPUT_DOPPLER_TOKEN" ]; then
                log_error "doppler-token input is required when using doppler provider"
                exit 1
            fi

            # Install Doppler CLI if not available
            if ! command -v doppler &> /dev/null; then
                log_info "Installing Doppler CLI..."
                curl -Ls --tlsv1.2 --proto "=https" --retry 3 https://cli.doppler.com/install.sh | sh
            fi

            # Build doppler secrets get command
            local doppler_cmd="doppler secrets get ${INPUT_DOPPLER_KEY_NAME} --plain"

            if [ -n "$INPUT_DOPPLER_PROJECT" ]; then
                doppler_cmd="$doppler_cmd --project ${INPUT_DOPPLER_PROJECT}"
            fi

            if [ -n "$INPUT_DOPPLER_CONFIG" ]; then
                doppler_cmd="$doppler_cmd --config ${INPUT_DOPPLER_CONFIG}"
            fi

            # Fetch secret from Doppler
            log_info "Fetching secret from Doppler..."
            export DOPPLER_TOKEN="$INPUT_DOPPLER_TOKEN"

            api_key=$(eval "$doppler_cmd" 2>&1)

            if [ $? -ne 0 ] || [ -z "$api_key" ]; then
                log_error "Failed to fetch secret from Doppler"
                log_error "Command: $doppler_cmd"
                log_error "Error: $api_key"
                exit 1
            fi

            log_info "API key successfully retrieved from Doppler"
            ;;

        1password|onepassword)
            log_info "Using 1Password secret provider"

            if [ -z "$INPUT_ONEPASSWORD_SERVICE_ACCOUNT_TOKEN" ]; then
                log_error "onepassword-service-account-token input is required when using 1password provider"
                exit 1
            fi

            # Install 1Password CLI if not available
            if ! command -v op &> /dev/null; then
                log_info "Installing 1Password CLI..."

                # Detect OS and install accordingly
                if [[ "$OSTYPE" == "linux-gnu"* ]]; then
                    curl -sS https://downloads.1password.com/linux/keys/1password.asc | \
                        gpg --dearmor --output /usr/share/keyrings/1password-archive-keyring.gpg
                    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/$(dpkg --print-architecture) stable main" | \
                        tee /etc/apt/sources.list.d/1password.list
                    mkdir -p /etc/debsig/policies/AC2D62742012EA22/
                    curl -sS https://downloads.1password.com/linux/debian/debsig/1password.pol | \
                        tee /etc/debsig/policies/AC2D62742012EA22/1password.pol
                    mkdir -p /usr/share/debsig/keyrings/AC2D62742012EA22
                    curl -sS https://downloads.1password.com/linux/keys/1password.asc | \
                        gpg --dearmor --output /usr/share/debsig/keyrings/AC2D62742012EA22/debsig.gpg
                    apt update && apt install -y 1password-cli
                elif [[ "$OSTYPE" == "darwin"* ]]; then
                    brew install 1password-cli
                else
                    log_error "Unsupported OS for automatic 1Password CLI installation"
                    exit 1
                fi
            fi

            # Set service account token
            export OP_SERVICE_ACCOUNT_TOKEN="$INPUT_ONEPASSWORD_SERVICE_ACCOUNT_TOKEN"

            # Build op read command
            local op_reference=""

            if [ -n "$INPUT_ONEPASSWORD_VAULT" ]; then
                op_reference="op://${INPUT_ONEPASSWORD_VAULT}/${INPUT_ONEPASSWORD_ITEM}/${INPUT_ONEPASSWORD_FIELD}"
            else
                op_reference="op://${INPUT_ONEPASSWORD_ITEM}/${INPUT_ONEPASSWORD_FIELD}"
            fi

            log_info "Fetching secret from 1Password..."
            log_info "Reference: $op_reference"

            api_key=$(op read "$op_reference" 2>&1)

            if [ $? -ne 0 ] || [ -z "$api_key" ]; then
                log_error "Failed to fetch secret from 1Password"
                log_error "Reference: $op_reference"
                log_error "Error: $api_key"
                exit 1
            fi

            log_info "API key successfully retrieved from 1Password"
            ;;

        *)
            log_error "Unknown provider: $provider"
            log_error "Supported providers: raw, doppler, 1password"
            exit 1
            ;;
    esac

    # Validate API key format
    if [ -z "$api_key" ]; then
        log_error "API key is empty after retrieval"
        exit 1
    fi

    # Mask the API key in logs
    mask_value "$api_key"

    # Export to environment variable
    local env_var_name="${INPUT_EXPORT_ENV_VAR:-ANTHROPIC_API_KEY}"
    export_env_var "$env_var_name" "$api_key"

    # Set GitHub output if requested
    if [ "${INPUT_SET_GITHUB_OUTPUT:-true}" == "true" ]; then
        set_output "api-key" "$api_key"
        log_info "API key set as GitHub output (masked)"
    fi

    log_info "✓ Authentication successful!"
}

# Run authentication
authenticate
