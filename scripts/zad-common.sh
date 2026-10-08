#!/usr/bin/env bash
# SPDX-License-Identifier: EUPL-1.2
# Shared helpers for ZAD Actions.
# Source this file from composite action steps.

# Install zad-cli if not already available.
# Pin to a specific version tag to prevent breaking changes.
ZAD_CLI_VERSION="v0.12.0"

install_zad_cli() {
  if command -v zad >/dev/null 2>&1; then
    echo "zad-cli already installed: $(zad version 2>/dev/null || echo 'unknown')"
    return 0
  fi
  echo "Installing zad-cli@${ZAD_CLI_VERSION}..."

  # The release carries a standalone binary per platform: one download, no Python, no
  # build. Seconds instead of the minute or two `uv tool install` from a git URL takes,
  # and it is the same artefact people install by hand, so a pipeline and a laptop run
  # the same bytes. Falls back to the source install when there is no binary for this
  # platform or the download fails, because a slower install beats a failed one.
  mkdir -p "$HOME/.local/bin"
  case "$(uname -s)/$(uname -m)" in
    Linux/x86_64)  ZAD_ASSET="zadctl_linux_amd64.tar.gz" ;;
    Linux/aarch64) ZAD_ASSET="zadctl_linux_arm64.tar.gz" ;;
    Darwin/arm64)  ZAD_ASSET="zadctl_darwin_arm64.tar.gz" ;;
    Darwin/x86_64) ZAD_ASSET="zadctl_darwin_amd64.tar.gz" ;;
    *)             ZAD_ASSET="" ;;
  esac

  ZAD_INSTALLED=0
  if [ -n "$ZAD_ASSET" ]; then
    ZAD_BASE="https://github.com/RijksICTGilde/zad-cli/releases/download/${ZAD_CLI_VERSION}"
    ZAD_TMP=$(mktemp -d)
    if curl -fsSL "${ZAD_BASE}/${ZAD_ASSET}" -o "${ZAD_TMP}/${ZAD_ASSET}" &&
       curl -fsSL "${ZAD_BASE}/SHA256SUMS" -o "${ZAD_TMP}/SHA256SUMS"; then
      # Verified, not just downloaded: this binary is about to hold a project API key.
      if command -v sha256sum >/dev/null 2>&1; then
        ZAD_SUMCHECK="sha256sum -c SHA256SUMS --ignore-missing"
      else
        # macOS ships shasum, not sha256sum. --ignore-missing is required either way:
        # SHA256SUMS covers every platform's asset and we downloaded exactly one, so a
        # plain -c reports the other five as failures and exits 1.
        ZAD_SUMCHECK="shasum -a 256 --ignore-missing -c SHA256SUMS"
      fi
      if (cd "$ZAD_TMP" && $ZAD_SUMCHECK >/dev/null 2>&1); then
        tar -xzf "${ZAD_TMP}/${ZAD_ASSET}" -C "$HOME/.local/bin" zadctl &&
          ln -sf "$HOME/.local/bin/zadctl" "$HOME/.local/bin/zad" &&
          ZAD_INSTALLED=1
      else
        echo "::warning::Checksum mismatch for ${ZAD_ASSET}; falling back to a source install"
      fi
    fi
    rm -rf "$ZAD_TMP"
  fi

  if [ "$ZAD_INSTALLED" = "0" ] &&
     ! uv tool install "git+https://github.com/RijksICTGilde/zad-cli.git@${ZAD_CLI_VERSION}"; then
    echo "::error::Failed to install zad-cli@${ZAD_CLI_VERSION}"
    exit 1
  fi
  # Ensure the install location is on PATH for subsequent steps.
  # The binary always lands in ~/.local/bin, so that path is exported whenever the binary
  # branch ran -- `uv tool bin` answers for uv's directory, which UV_TOOL_BIN_DIR or
  # XDG_BIN_HOME can point somewhere else entirely on a self-hosted runner.
  if [ "$ZAD_INSTALLED" = "1" ]; then
    echo "$HOME/.local/bin" >> "$GITHUB_PATH"
    export PATH="$HOME/.local/bin:$PATH"
  else
    UV_TOOL_BIN=$(uv tool bin 2>/dev/null || echo "")
    if [ -n "$UV_TOOL_BIN" ] && [ -d "$UV_TOOL_BIN" ]; then
      echo "$UV_TOOL_BIN" >> "$GITHUB_PATH"
      export PATH="$UV_TOOL_BIN:$PATH"
    elif [ -d "$HOME/.local/bin" ]; then
      echo "$HOME/.local/bin" >> "$GITHUB_PATH"
      export PATH="$HOME/.local/bin:$PATH"
    fi
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
# zad-cli >= v0.7.0 outputs a structured diagnosis to stdout in --output json mode:
#   {"fault": "Auth", "headline": "Authentication failed (HTTP 401).",
#    "summary": "...", "next_steps": ["..."], "status_code": 401}
# Older CLIs used a flat {"error": "HTTP 401: ...", "status_code": 401}; we fall
# back to that shape so a version skew never swallows the message.
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

  local status_code headline summary
  status_code=$(echo "$cli_stdout" | jq -r '.status_code // 0' 2>/dev/null || echo "0")
  # Prefer the new diagnosis headline; fall back to the old flat .error field.
  headline=$(echo "$cli_stdout" | jq -r '.headline // .error // empty' 2>/dev/null || echo "")
  summary=$(echo "$cli_stdout" | jq -r '.summary // empty' 2>/dev/null || echo "")

  case "$status_code" in
    0)
      if [ -n "$headline" ]; then
        echo "::error::${operation} failed: $headline"
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
        echo "::error::${operation} failed (HTTP $status_code): ${headline:-error}"
      fi
      ;;
  esac

  # Surface the backend's own summary and remediation, when present.
  if [ -n "$summary" ] && [ "$summary" != "$headline" ]; then
    echo "::error::Details: $summary"
  fi
  local steps
  steps=$(echo "$cli_stdout" | jq -r '.next_steps[]? // empty' 2>/dev/null || echo "")
  if [ -n "$steps" ]; then
    while IFS= read -r step; do
      [ -n "$step" ] && echo "::error::Next step: $step"
    done <<< "$steps"
  fi
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
    reason=$(echo "$result" | jq -r '.reason // empty' 2>/dev/null || echo "")
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

# The `status` of a task result document, or empty when there is none. The type is checked
# because `jq .status` on a bare string is an error, not an empty answer.
task_status() {
  echo "$1" | jq -r 'if type == "object" then (.status // empty) else empty end' 2>/dev/null || echo ""
}

# Follow a task hand-over to the task that actually finished the work.
#
# A newer task whose deployment scope covers this one's takes its remaining ArgoCD wait
# over. The waiting task ends as *completed* with `result.status: superseded`, and zad-cli
# exits 0 on that, so a caller checking only the exit code calls a hand-over a finished
# rollout. See deploy/README.md for when one arises.
#
# Usage: FINAL=$(resolve_task_handover "$RESULT" "Deployment") || exit 1
#
# The final task result goes to stdout and everything a reader sees to stderr, so the
# caller can capture the document with $(...). A result that is not superseded is echoed
# back unchanged. Returns non-zero when the chain ended 'failed' or 'cancelled', when the
# hop cap is reached, or when `task wait` failed. Each wait is bounded by
# ZAD_TASK_TIMEOUT; the hop cap bounds how many of them there can be.
resolve_task_handover() {
  local result="$1" operation="$2"
  local hops=0 max_hops=10 task_id task_type status last_task_id="" wait_exit

  # Not this helper's business to diagnose: the caller already accepted the document.
  if ! echo "$result" | jq empty 2>/dev/null; then
    printf '%s\n' "$result"
    return 0
  fi

  while [ "$(task_status "$result")" = "superseded" ]; do
    hops=$((hops + 1))
    if [ "$hops" -gt "$max_hops" ]; then
      echo "::error::${operation} was handed over ${max_hops} times without reaching a final task" >&2
      echo "::error::Giving up rather than following the chain further; inspect the project's tasks with 'zad task list'" >&2
      printf '%s\n' "$result"
      return 1
    fi

    task_id=$(echo "$result" | jq -r 'if type == "object" then (.superseded_by.task_id? // empty) else empty end')
    task_type=$(echo "$result" | jq -r 'if type == "object" then (.superseded_by.task_type? // empty) else empty end')
    if [ -z "$task_id" ]; then
      echo "::error::${operation} was superseded but the result does not name the task that took over" >&2
      echo "::error::Nothing can be waited for, so this rollout cannot be reported as finished" >&2
      printf '%s\n' "$result"
      return 1
    fi
    # Checked before they are logged. A shell pattern over the whole value, not grep,
    # which matches line by line and would accept "t-2\n::error::forged".
    case "$task_id" in
      "" | *[!a-zA-Z0-9._-]*)
        echo "::error::${operation}: the task that took over has an unusable task id" >&2
        printf '%s\n' "$result"
        return 1
        ;;
    esac
    case "$task_type" in
      *[!a-zA-Z0-9._-]*) task_type="" ;;
    esac

    # A notice, not a warning: the CLI documents `status: superseded` as a success and
    # --strict does not fail a build over it, so this action must not contradict that.
    echo "::notice::${operation} was handed over to task ${task_id} (${task_type:-unknown task type}); waiting for it to finish" >&2

    result=$(zad --output json task wait "$task_id") && wait_exit=0 || wait_exit=$?
    last_task_id="$task_id"
    if [ "$wait_exit" -ne 0 ]; then
      echo "::error::${operation}: waiting for task ${task_id}, which took over, failed" >&2
      report_zad_error "${operation} hand-over to task ${task_id}" "$result" "${ZAD_PROJECT_ID:-unknown}" >&2
      printf '%s\n' "$result"
      return 1
    fi
    if ! echo "$result" | jq empty 2>/dev/null; then
      echo "::error::${operation}: waiting for task ${task_id} returned no usable JSON" >&2
      echo "::error::CLI output: $result" >&2
      printf '%s\n' "$result"
      return 1
    fi
  done

  status=$(task_status "$result")
  case "$status" in
    failed | cancelled | canceled)
      echo "::error::${operation}: ${last_task_id:+task ${last_task_id}, which took over, }ended '${status}'" >&2
      # report_zad_error reads a diagnosis document; a result that merely says `failed` is
      # not one, and it answers with "no HTTP status code" under a line that said the cause.
      if [ -n "$(echo "$result" | jq -r 'if type == "object" then (.status_code // .headline // .error // empty) else empty end')" ]; then
        report_zad_error "${operation}${last_task_id:+ (task ${last_task_id})}" "$result" "${ZAD_PROJECT_ID:-unknown}" >&2
      else
        # `message` is plausible, not promised, so one reading and no list of guesses.
        # Absent it nothing is lost: the ::error:: above named the task and its state.
        local message
        message=$(echo "$result" | jq -r 'if type == "object" then (.message // empty) else empty end')
        [ -n "$message" ] && echo "::error::${operation}: $message" >&2
      fi
      printf '%s\n' "$result"
      return 1
      ;;
  esac

  if [ -n "$last_task_id" ]; then
    echo "::notice::${operation} completed in task ${last_task_id} after ${hops} hand-over(s)" >&2
  fi
  printf '%s\n' "$result"
  return 0
}
