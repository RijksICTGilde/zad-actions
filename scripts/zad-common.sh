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
  uv tool install "git+https://github.com/RijksICTGilde/zad-cli.git@${ZAD_CLI_VERSION}"
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

  local status_code error_msg
  status_code=$(echo "$cli_stdout" | jq -r '.status_code // 0' 2>/dev/null || echo "0")
  error_msg=$(echo "$cli_stdout" | jq -r '.error // empty' 2>/dev/null || echo "")

  case "$status_code" in
    0)
      if [ -n "$error_msg" ]; then
        echo "::error::${operation} failed: $error_msg"
      else
        echo "::error::${operation} failed: Unable to connect to ZAD API"
        echo "::error::This could be a network issue or the API may be unavailable"
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

  local result zad_exit
  result=$(zad --output json deployment delete "$deployment_name" --yes --ignore-not-found) && zad_exit=0 || zad_exit=$?

  if [ "$zad_exit" -eq 0 ]; then
    local reason
    reason=$(echo "$result" | jq -r '.reason // empty' 2>/dev/null)
    if [ "$reason" = "not_found" ]; then
      DELETE_RESULT="false"
      DELETE_REASON="not_found"
    else
      DELETE_RESULT="true"
      DELETE_REASON=""
    fi
  else
    DELETE_RESULT="false"
    DELETE_REASON="error"
    # Use warning level (cleanup failures are non-fatal)
    report_zad_error "Delete '$deployment_name'" "$result" "${ZAD_PROJECT_ID:-unknown}"
  fi
}
