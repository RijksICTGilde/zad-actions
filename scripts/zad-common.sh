#!/usr/bin/env bash
# SPDX-License-Identifier: EUPL-1.2
# Shared helpers for ZAD Actions (curl_with_retry, poll_task).
# Source this file from composite action steps.
#
# Required environment variables:
#   MAX_RETRIES, RETRY_DELAY        — for curl_with_retry
#   TASK_TIMEOUT, TASK_POLL_INTERVAL — for poll_task
#   ZAD_API_KEY                      — for poll_task (API authentication)

# Retry helper: curl_with_retry URL [curl_args...]
# Uses MAX_RETRIES and RETRY_DELAY from environment.
# Sets FINAL_HTTP_CODE and FINAL_BODY after completion.
# shellcheck disable=SC2034  # FINAL_BODY is used by the sourcing script
curl_with_retry() {
  local url="$1"; shift
  local attempt=0
  local delay="$RETRY_DELAY"
  while true; do
    local response
    response=$(curl -s -w "\n%{http_code}" --max-time 60 "$@" "$url")
    FINAL_HTTP_CODE=$(echo "$response" | tail -n1)
    FINAL_BODY=$(echo "$response" | sed '$d')

    # Success
    if [ "$FINAL_HTTP_CODE" -ge 200 ] && [ "$FINAL_HTTP_CODE" -lt 300 ]; then
      return 0
    fi

    # Determine if retryable
    local retryable=false
    if [ "$FINAL_HTTP_CODE" -eq 000 ] || [ "$FINAL_HTTP_CODE" -eq 429 ]; then
      retryable=true
    elif [ "$FINAL_HTTP_CODE" -ge 500 ] && [ "$FINAL_HTTP_CODE" -le 504 ]; then
      retryable=true
    fi

    if [ "$retryable" = "true" ] && [ "$attempt" -lt "$MAX_RETRIES" ]; then
      attempt=$((attempt + 1))
      echo "::warning::Transient error (HTTP $FINAL_HTTP_CODE), retrying in ${delay}s (attempt $attempt/$MAX_RETRIES)..."
      sleep "$delay"
      delay=$((delay * 2))
      continue
    fi

    # Non-retryable or retries exhausted
    return 1
  done
}

# Poll async task until completion.
# Sets TASK_RESULT on success. Returns non-zero on failure/timeout.
# shellcheck disable=SC2034  # TASK_RESULT is used by the sourcing script
poll_task() {
  local poll_url="$1"
  local elapsed=0
  while [ "$elapsed" -lt "$TASK_TIMEOUT" ]; do
    local response
    response=$(curl -s -w "\n%{http_code}" --max-time 60 \
      -H "X-API-Key: $ZAD_API_KEY" \
      "$poll_url")
    local http_code body status
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')

    if [ "$http_code" -ge 400 ] && [ "$http_code" -lt 500 ]; then
      echo "::error::Task poll returned HTTP $http_code (non-retryable)"
      return 1
    fi

    if [ "$http_code" -lt 200 ] || [ "$http_code" -ge 300 ]; then
      echo "::warning::Task poll returned HTTP $http_code, retrying..."
      sleep "$TASK_POLL_INTERVAL"
      continue
    fi

    status=$(echo "$body" | jq -r '.status' 2>/dev/null)
    case "$status" in
      completed)
        TASK_RESULT="$body"
        return 0
        ;;
      failed|cancelled)
        local error_msg
        error_msg=$(echo "$body" | jq -r '.error_message // .result.error // "unknown error"' 2>/dev/null)
        echo "::error::Task $status: $error_msg"
        TASK_RESULT="$body"
        return 1
        ;;
      pending|claimed|running)
        local step percent
        step=$(echo "$body" | jq -r '.current_step // empty' 2>/dev/null)
        percent=$(echo "$body" | jq -r '.progress_percent // 0' 2>/dev/null)
        if [ -n "$step" ]; then
          echo "Task $status (${percent}%): $step"
        fi
        ;;
      *)
        echo "::warning::Unknown task status: $status"
        ;;
    esac

    sleep "$TASK_POLL_INTERVAL"
    elapsed=$((elapsed + TASK_POLL_INTERVAL))
  done
  echo "::error::Task polling timed out after ${TASK_TIMEOUT}s"
  return 1
}

# Build full poll URL from API response.
# If poll_url is already absolute (starts with http), use it directly.
# Otherwise, treat as path relative to the API host (strip /api suffix
# from API_BASE_URL, e.g. https://host/api -> https://host).
build_poll_url() {
  local poll_url="$1"
  if [[ "$poll_url" == http* ]]; then
    echo "$poll_url"
  elif [[ "$API_BASE_URL" == */api ]]; then
    echo "${API_BASE_URL%/api}${poll_url}"
  else
    echo "${API_BASE_URL%/}${poll_url}"
  fi
}
