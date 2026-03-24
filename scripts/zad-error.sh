#!/usr/bin/env bash
# SPDX-License-Identifier: EUPL-1.2
# Parse zad-cli JSON error output and emit GitHub Actions annotations.
#
# Usage: report_zad_error <operation> <stdout> <project-id>
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
