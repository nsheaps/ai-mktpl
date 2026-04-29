#!/usr/bin/env bash
# install-op.sh — SessionStart hook for 1pass plugin
#
# On web sessions: installs/updates 1Password CLI (op) and op-exec.
# On all sessions: injects configured 1Password secrets as environment variables.
#
# When installToProject is true, installs to $CLAUDE_PROJECT_DIR/bin/.local/
# which is gitignored and added to PATH.
set -euo pipefail

PLUGIN_NAME="1pass"
source "${CLAUDE_PLUGIN_ROOT}/lib/plugin-config-read.sh"
source "${CLAUDE_PLUGIN_ROOT}/lib/tool-install.sh"
source "${CLAUDE_PLUGIN_ROOT}/lib/hook-logging.sh"

# --- Guards ---

plugin_is_enabled || { hook_log "plugin disabled, skipping"; hook_respond; exit 0; }

# --- Read config ---

auto_install="$(plugin_get_config "autoInstall" "false")"
op_version="$(plugin_get_config "opVersion" "latest")"
install_op_exec="$(plugin_get_config "installOpExec" "false")"
op_exec_version="$(plugin_get_config "opExecVersion" "latest")"
secrets_json="$(plugin_get_config_json "secrets" "[]")"

tool_resolve_install_dir

# --- Platform detection ---

detect_platform() {
  local os arch
  os="$(uname -s | tr '[:upper:]' '[:lower:]')"
  arch="$(uname -m)"

  case "$arch" in
    x86_64)  arch="amd64" ;;
    aarch64|arm64) arch="arm64" ;;
    i386|i686) arch="386" ;;
    *)
      hook_fail "platform detection" "Unsupported architecture: $arch" \
        "This plugin supports x86_64, arm64, and i386 architectures"
      return 1
      ;;
  esac

  case "$os" in
    linux|darwin) ;;
    *)
      hook_fail "platform detection" "Unsupported OS: $os" \
        "This plugin supports Linux and macOS only"
      return 1
      ;;
  esac

  DETECTED_OS="$os"
  DETECTED_ARCH="$arch"
}

# --- Version resolution ---

# Resolve the latest op CLI version from 1Password's update endpoint.
# 1Password/cli is not a public GitHub repo, so we can't use tool_resolve_github_version.
# Falls back to a hardcoded version on failure.
resolve_latest_op_version() {
  local fallback="2.32.1"
  local version=""
  version="$(curl -fsSL "https://app-updates.agilebits.com/check/1/0/CLI2/en/2.0.0/N" 2>/dev/null \
    | grep -o '"version":"[^"]*"' | sed 's/"version":"//;s/"//' || true)"
  if [ -z "$version" ]; then
    hook_log "Could not determine latest op version, using fallback $fallback"
    version="$fallback"
  fi
  echo "$version"
}

# --- Download helpers ---

download_op() {
  hook_log_step "download-op" "Downloading 1Password CLI"
  local target_version="$1"
  local op_bin="$INSTALL_DIR/op"
  local tmp_dir
  tmp_dir="$(mktemp -d)"
  local archive="op_${DETECTED_OS}_${DETECTED_ARCH}_v${target_version}.zip"
  local url="https://cache.agilebits.com/dist/1P/op2/pkg/v${target_version}/${archive}"

  hook_log "Downloading op v${target_version} from ${url}"

  if curl -fsSL "$url" -o "$tmp_dir/$archive" 2>/dev/null; then
    if command -v unzip >/dev/null 2>&1; then
      unzip -o -q "$tmp_dir/$archive" -d "$tmp_dir"
    else
      # Fallback: use python to unzip
      python3 -c "import zipfile; zipfile.ZipFile('$tmp_dir/$archive').extractall('$tmp_dir')"
    fi
    cp "$tmp_dir/op" "$op_bin"
    chmod +x "$op_bin"
    rm -rf "$tmp_dir"
    hook_log "op v${target_version} installed to ${op_bin}"
    tool_ensure_path "$INSTALL_DIR"
    echo "$op_bin"
  else
    rm -rf "$tmp_dir"
    hook_fail "op download" "Failed to download op v${target_version} from ${url}" \
      "Check network connectivity, or set opVersion to a specific version in plugin settings"
    return 1
  fi
}

download_op_exec() {
  hook_log_step "download-op-exec" "Downloading op-exec"
  local target_version="$1"
  local op_exec_bin="$INSTALL_DIR/op-exec"
  local url="https://github.com/nsheaps/op-exec/releases/download/v${target_version}/op-exec-${DETECTED_OS}-${DETECTED_ARCH}"

  hook_log "Downloading op-exec v${target_version} from ${url}"

  if curl -fsSL "$url" -o "$op_exec_bin" 2>/dev/null; then
    chmod +x "$op_exec_bin"
    hook_log "op-exec v${target_version} installed to ${op_exec_bin}"
    tool_ensure_path "$INSTALL_DIR"
    echo "$op_exec_bin"
  else
    hook_fail "op-exec download" "Failed to download op-exec v${target_version} from ${url}" \
      "Check network connectivity, or verify the release exists at https://github.com/nsheaps/op-exec/releases"
    return 1
  fi
}

# --- Resolve op binary ---

resolve_op_bin() {
  hook_log_step "resolve-op" "Resolving 1Password CLI binary"
  if [ "$auto_install" = "false" ]; then
    if tool_is_available op; then
      hook_log "autoInstall=false, using op from PATH"
      command -v op
    else
      hook_log "autoInstall=false and op not on PATH, skipping"
      return 1
    fi
    return
  fi

  local op_bin="$INSTALL_DIR/op"

  if [ -x "$op_bin" ]; then
    if [ "$op_version" = "latest" ]; then
      local current_version latest_version
      current_version="$("$op_bin" --version 2>/dev/null || echo "unknown")"
      latest_version="$(resolve_latest_op_version)"
      if [ "$current_version" = "$latest_version" ]; then
        hook_log "op $current_version is already latest"
        echo "$op_bin"
      else
        hook_log "Updating op from $current_version to $latest_version"
        download_op "$latest_version"
      fi
    else
      echo "$op_bin"
    fi
  elif tool_is_available op; then
    hook_log "op found on PATH ($(command -v op)), skipping install"
    command -v op
  else
    hook_log "Installing op to $INSTALL_DIR"
    local install_version="$op_version"
    if [ "$install_version" = "latest" ]; then
      install_version="$(resolve_latest_op_version)"
    fi
    download_op "$install_version"
  fi
}

# --- Resolve op-exec binary ---

resolve_op_exec_bin() {
  hook_log_step "resolve-op-exec" "Resolving op-exec binary"
  if [ "$install_op_exec" = "false" ]; then
    if tool_is_available op-exec; then
      hook_log "installOpExec=false, using op-exec from PATH"
      command -v op-exec
    else
      hook_log "installOpExec=false and op-exec not on PATH, skipping"
      return 1
    fi
    return
  fi

  local op_exec_bin="$INSTALL_DIR/op-exec"

  if [ -x "$op_exec_bin" ]; then
    if [ "$op_exec_version" = "latest" ]; then
      local current_version latest_version
      current_version="$("$op_exec_bin" --version 2>/dev/null || echo "unknown")"
      latest_version="$(tool_resolve_github_version "nsheaps/op-exec" "0.0.1")"
      if [ "$current_version" = "$latest_version" ]; then
        hook_log "op-exec $current_version is already latest"
        echo "$op_exec_bin"
      else
        hook_log "Updating op-exec from $current_version to $latest_version"
        download_op_exec "$latest_version"
      fi
    else
      echo "$op_exec_bin"
    fi
  elif tool_is_available op-exec; then
    hook_log "op-exec found on PATH ($(command -v op-exec)), skipping install"
    command -v op-exec
  else
    hook_log "Installing op-exec to $INSTALL_DIR"
    local install_version="$op_exec_version"
    if [ "$install_version" = "latest" ]; then
      install_version="$(tool_resolve_github_version "nsheaps/op-exec" "0.0.1")"
    fi
    download_op_exec "$install_version"
  fi
}

# --- Secrets injection ---

# Write a key=value pair to the specified target.
# Args: $1=env_var $2=value $3=target (envFile|settingsJson|settingsLocalJson|userSettingsJson)
_write_secret() {
  local env_var="$1" value="$2" target="${3:-envFile}"

  case "$target" in
    envFile)
      if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
        # Remove any existing export of this var to avoid duplicates
        if [ -f "$CLAUDE_ENV_FILE" ]; then
          local tmp_env
          tmp_env="$(mktemp)"
          grep -v "^export ${env_var}=" "$CLAUDE_ENV_FILE" > "$tmp_env" 2>/dev/null || true
          mv "$tmp_env" "$CLAUDE_ENV_FILE"
        fi
        printf 'export %s=%q\n' "$env_var" "$value" >> "$CLAUDE_ENV_FILE"
        export "${env_var}=${value}"
        hook_log "Injected ${env_var} via CLAUDE_ENV_FILE"
      else
        hook_log "CLAUDE_ENV_FILE not set, falling back to current environment only"
        export "${env_var}=${value}"
      fi
      ;;
    settingsJson|settingsLocalJson|userSettingsJson)
      local settings_file
      case "$target" in
        settingsJson)      settings_file="${CLAUDE_PROJECT_DIR:-.}/.claude/settings.json" ;;
        settingsLocalJson) settings_file="${CLAUDE_PROJECT_DIR:-.}/.claude/settings.local.json" ;;
        userSettingsJson)  settings_file="${HOME}/.claude/settings.json" ;;
      esac
      mkdir -p "$(dirname "$settings_file")"
      if [ ! -f "$settings_file" ]; then
        echo '{}' > "$settings_file"
      fi
      local tmp_settings
      tmp_settings="$(mktemp)"
      jq --arg k "$env_var" --arg v "$value" '.env[$k] = $v' "$settings_file" > "$tmp_settings"
      mv "$tmp_settings" "$settings_file"
      hook_log "Injected ${env_var} into ${settings_file} env block"
      ;;
    *)
      hook_fail "secrets injection" "Unknown target '${target}' for ${env_var}" \
        "Valid targets: envFile, settingsJson, settingsLocalJson, userSettingsJson"
      ;;
  esac
}

# Inject secrets from the configured secrets list using op read.
# Requires op to be available and authenticated.
inject_secrets() {
  # Skip if no secrets configured
  local secret_count
  secret_count="$(echo "$secrets_json" | jq 'length' 2>/dev/null || echo "0")"
  if [ "$secret_count" = "0" ] || [ "$secret_count" = "null" ]; then
    hook_log "No secrets configured, skipping injection"
    return 0
  fi

  hook_log_step "inject-secrets" "Injecting ${secret_count} secret(s) from 1Password"

  # Verify op is available
  local op_bin
  if tool_is_available op; then
    op_bin="$(command -v op)"
  elif [ -x "${INSTALL_DIR:-}/op" ]; then
    op_bin="${INSTALL_DIR}/op"
  else
    hook_fail "secrets injection" "op not available" \
      "Set autoInstall: true or install op manually. Cannot inject secrets without op."
    return 1
  fi

  # Verify op is authenticated
  if ! "$op_bin" whoami &>/dev/null; then
    hook_fail "secrets injection" "op not authenticated" \
      "Set OP_SERVICE_ACCOUNT_TOKEN env var, or sign in with 'op signin' on local sessions"
    return 1
  fi

  # Iterate over each secret entry
  local i=0
  while [ "$i" -lt "$secret_count" ]; do
    local entry env_var reference target
    entry="$(echo "$secrets_json" | jq -c ".[$i]")"
    env_var="$(echo "$entry" | jq -r '.envVar // empty')"
    reference="$(echo "$entry" | jq -r '.reference // empty')"
    target="$(echo "$entry" | jq -r '.target // "envFile"')"

    if [ -z "$env_var" ] || [ -z "$reference" ]; then
      hook_fail "secrets injection" "Secret entry $i missing required fields" \
        "Each secret entry must have 'envVar' and 'reference' fields"
      i=$((i + 1))
      continue
    fi

    hook_log "Reading secret ${env_var} from ${reference}"
    local secret_value
    if secret_value="$("$op_bin" read "$reference" 2>/dev/null)"; then
      _write_secret "$env_var" "$secret_value" "$target"
    else
      hook_fail "secrets injection" "Failed to read ${reference} for ${env_var}" \
        "Check the reference path and that op has access to the vault"
    fi

    i=$((i + 1))
  done
}

# --- Main ---

do_install() {
  # Install op CLI (web sessions only)
  local op_bin=""
  local op_exec_bin=""

  # Platform detection must happen before EITHER tool install — both op and
  # op-exec download helpers need DETECTED_OS / DETECTED_ARCH.
  if ! tool_is_available op || ! tool_is_available op-exec; then
    detect_platform || return 0
  fi

  if ! tool_is_available op; then
    op_bin="$(resolve_op_bin)" || true
  else
    hook_log "op already available at $(command -v op), skipping op install"
  fi

  if ! tool_is_available op-exec; then
    op_exec_bin="$(resolve_op_exec_bin)" || true
  else
    hook_log "op-exec already available at $(command -v op-exec), skipping op-exec install"
  fi

  # Inject secrets (all sessions — requires op to be available and authenticated)
  inject_secrets || true

  # Report tool availability to agent
  if [ -n "${op_bin:-}" ] && [ -x "${op_bin:-}" ]; then
    local op_ver
    op_ver="$("$op_bin" --version 2>/dev/null || echo "unknown")"
    hook_log "op v${op_ver} available at ${op_bin}"
  elif tool_is_available op; then
    local op_ver
    op_ver="$(op --version 2>/dev/null || echo "unknown")"
    hook_log "op v${op_ver} available at $(command -v op)"
  fi

  if [ -n "${op_exec_bin:-}" ] && [ -x "${op_exec_bin:-}" ]; then
    local opx_ver
    opx_ver="$("$op_exec_bin" --version 2>/dev/null || echo "unknown")"
    hook_log "op-exec v${opx_ver} available at ${op_exec_bin}"
  fi
}

# --- Execute ---

tool_run_install do_install
hook_log_cleanup
hook_respond
