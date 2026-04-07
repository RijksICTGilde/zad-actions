#!/usr/bin/env bash
# SPDX-License-Identifier: EUPL-1.2
# Shared helpers for ZAD Actions.
# Source this file from composite action steps.

# Install zad-cli if not already available.
# Pin to a specific version tag to prevent breaking changes.
ZAD_CLI_VERSION="v0.1.1"

install_zad_cli() {
  if command -v zad >/dev/null 2>&1; then
    echo "zad-cli already installed: $(zad version 2>/dev/null || echo 'unknown')"
    return 0
  fi
  echo "Installing zad-cli@${ZAD_CLI_VERSION}..."
  if ! uv tool install "git+https://github.com/RijksICTGilde/zad-cli.git@${ZAD_CLI_VERSION}"; then
    echo "::error::Failed to install zad-cli@${ZAD_CLI_VERSION}"
    exit 1
  fi
  # Ensure uv tool bin directory is on PATH for subsequent steps
  UV_TOOL_BIN=$(uv tool bin 2>/dev/null || echo "")
  if [ -n "$UV_TOOL_BIN" ] && [ -d "$UV_TOOL_BIN" ]; then
    echo "$UV_TOOL_BIN" >> "$GITHUB_PATH"
    export PATH="$UV_TOOL_BIN:$PATH"
  elif [ -d "$HOME/.local/bin" ]; then
    echo "$HOME/.local/bin" >> "$GITHUB_PATH"
    export PATH="$HOME/.local/bin:$PATH"
  fi
  if ! command -v zad >/dev/null 2>&1; then
    echo "::error::zad-cli installed but 'zad' command not found in PATH"
    exit 1
  fi
}

# Validate that a value matches the allowed character pattern.
# Usage: validate_input <name> <value> [allow_empty]
validate_input() {
  local name="$1" value="$2" allow_empty="${3:-false}"
  if [ -z "$value" ]; then
    if [ "$allow_empty" = "true" ]; then return 0; fi
    echo "Error: $name is required"
    exit 1
  fi
  if ! echo "$value" | grep -qE '^[a-zA-Z0-9._-]+$'; then
    echo "Error: $name contains invalid characters (allowed: a-z, A-Z, 0-9, ., _, -)"
    exit 1
  fi
}

# Validate that a value is a non-negative integer.
# Usage: validate_integer <name> <value>
validate_integer() {
  local name="$1" value="$2"
  if ! echo "$value" | grep -qE '^[0-9]+$'; then
    echo "Error: $name must be a non-negative integer"
    exit 1
  fi
}

# Parse zad-cli JSON error output and emit GitHub Actions annotations.
#
# Usage: report_zad_error <operation> <cli_stdout> <project-id>
#
# The CLI outputs JSON errors to stdout in --output json mode:
#   {"error": "HTTP 401: ...", "status_code": 401}
report_zad_error() {
  local operation="$1"
  local cli_stdout="$2"
  local project_id="$3"

  # Guard against non-JSON output (CLI crash, command not found, Python traceback)
  if ! echo "$cli_stdout" | jq empty 2>/dev/null; then
    echo "::error::${operation} failed: unexpected CLI output (not JSON)"
    echo "::error::CLI output: $cli_stdout"
    return
  fi

  local status_code error_msg
  status_code=$(echo "$cli_stdout" | jq -r '.status_code // 0' 2>/dev/null || echo "0")
  error_msg=$(echo "$cli_stdout" | jq -r '.error // empty' 2>/dev/null || echo "")

  case "$status_code" in
    0)
      if [ -n "$error_msg" ]; then
        echo "::error::${operation} failed: $error_msg"
      else
        echo "::error::${operation} failed with no HTTP status code"
        echo "::error::This could be a network issue, timeout, or CLI error"
      fi
      ;;
    401)
      echo "::error::${operation} failed: Authentication failed (HTTP 401)"
      echo "::error::Please verify your ZAD_API_KEY secret is correct and not expired"
      ;;
    403)
      echo "::error::${operation} failed: Access denied (HTTP 403)"
      echo "::error::Your API key may not have permission for project '$project_id'"
      ;;
    404)
      echo "::error::${operation} failed: Not found (HTTP 404)"
      echo "::error::Please verify project-id '$project_id' exists in ZAD"
      ;;
    *)
      if [ "$status_code" -ge 500 ] 2>/dev/null; then
        echo "::error::${operation} failed: ZAD API server error (HTTP $status_code) after retries"
      else
        echo "::error::${operation} failed (HTTP $status_code): $error_msg"
      fi
      ;;
  esac
}

# Delete a ZAD deployment via CLI, handling not-found gracefully.
# Sets DELETE_RESULT ("true", "false") and DELETE_REASON ("not_found", "error", "").
#
# Usage: zad_delete_deployment <deployment-name>
# shellcheck disable=SC2034  # DELETE_RESULT and DELETE_REASON are used by the sourcing script
zad_delete_deployment() {
  local deployment_name="$1"

  # Reset state (prevents stale values when called in a loop)
  DELETE_RESULT="false"
  DELETE_REASON=""

  local result zad_exit
  result=$(zad --output json deployment delete "$deployment_name" --yes --ignore-not-found) && zad_exit=0 || zad_exit=$?

  if [ "$zad_exit" -eq 0 ]; then
    local reason
    reason=$(echo "$result" | jq -r '.reason // empty' 2>/dev/null)
    if [ "$reason" = "not_found" ]; then
      DELETE_REASON="not_found"
    else
      DELETE_RESULT="true"
    fi
  else
    DELETE_REASON="error"
    # Use warning (not error) — cleanup failures are non-fatal
    echo "::warning::Failed to delete ZAD deployment '$deployment_name'"
    report_zad_error "Delete '$deployment_name'" "$result" "${ZAD_PROJECT_ID:-unknown}"
  fi
}
