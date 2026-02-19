---
name: debug-deploy
description: >-
  Diagnose falende ZAD deployments of cleanup actions. Gebruik bij 'deployment
  faalt', 'error', 'deploy werkt niet', 'cleanup faalt', 'HTTP error', '401',
  '403', '404'.
model: sonnet
allowed-tools:
  - Read(*)
  - Grep(*)
---

# Debug ZAD Deployment

Diagnose and troubleshoot failing ZAD deployments and cleanup actions.

## Usage

```
/debug-deploy <error message or description>
```

Example: `/debug-deploy HTTP 401`, `/debug-deploy deployment not reachable`

## Diagnostic decision tree

Analyze the error and match against these patterns:

### Bot PR skipping (deploy/cleanup)

Both deploy and cleanup actions skip bot PRs by default (`skip-bot-prs: 'true'`).

| Symptom | Diagnosis | Fix |
|---------|-----------|-----|
| Deployment/cleanup didn't run on a bot PR (dependabot, renovate, pre-commit-ci, github-actions) | Expected behavior — `skip-bot-prs` defaults to `true` | Set `skip-bot-prs: 'false'` to deploy bot PRs |
| `skipped` output is `true` | Bot PR detected via GitHub user type or known bot list | If intentional, no action needed. Otherwise set `skip-bot-prs: 'false'` |
| Deployment skipped for a non-bot PR | Check if the PR author has user type `Bot` in GitHub | Verify user account type. Custom bots with `[bot]` suffix are also detected |

### ZAD API errors (deploy/cleanup/scheduled-cleanup)

All three actions retry transient ZAD API errors (000, 429, 500-504) with exponential backoff. Auth errors (401, 403) and 404 are NOT retried. GitHub API calls are also not retried.

| HTTP Code | Diagnosis | Retried? | Fix |
|-----------|-----------|----------|-----|
| `000` | Network problem — runner can't reach ZAD API | Yes | Check runner network, verify `api-base-url` is correct. Default: `https://operations-manager.rig.prd1.gn2.quattro.rijksapps.nl/api` |
| `401` | API key invalid or expired | No | Regenerate `ZAD_API_KEY` in Operations Manager and update the repository secret |
| `403` | API key lacks permission for this project | No | Verify the API key has access to the specified `project-id`. Request access via Operations Manager |
| `404` | Project not found (deploy) / already deleted (cleanup) | No | Check `project-id` spelling. Verify project exists in ZAD Operations Manager |
| `429` | Rate limited | Yes | Automatically retried. Increase `retry-delay` if persistent |
| `5xx` | ZAD API server error | Yes | Automatically retried. If persistent after retries, check ZAD Operations Manager status |

### Deployment readiness errors (wait-for-ready)

| Symptom | Diagnosis | Fix |
|---------|-----------|-----|
| Timeout waiting for deployment | Container not starting or slow startup | Increase `wait-timeout` (default: 300s). Check container logs in ZAD. Verify `health-endpoint` returns HTTP 2xx/3xx |
| HTTP 502/503 from health endpoint | Container crashing or not listening on correct port | Check container listens on the expected port. Verify environment variables are set correctly in ZAD |

### GitHub environment deletion errors

| Symptom | Diagnosis | Fix |
|---------|-----------|-----|
| `403` on environment delete | Token lacks admin permission | `github-admin-token` must be a PAT with `repo` scope or a GitHub App token with `administration:write`. The default `GITHUB_TOKEN` cannot delete environments |
| Environment not deleted but no error | `github-admin-token` not provided | Set `github-admin-token: ${{ secrets.GITHUB_ADMIN_TOKEN }}` — this is a separate input from `github-token` |

### GitHub deployment deletion errors

| Symptom | Diagnosis | Fix |
|---------|-----------|-----|
| Can't delete deployments | Missing permission | Add `permissions: deployments: write` to the job. Use `github-token` (not admin token) |

### Container image deletion errors

| Symptom | Diagnosis | Fix |
|---------|-----------|-----|
| Can't delete container | Missing permission | The token needs `packages:delete` scope. For org packages, the token user must have admin access to the package |
| Container not found | Wrong org/name/tag | Verify `container-org`, `container-name`, and `container-tag` match exactly. Tag format is typically `pr-<number>` |

### PR comment errors

| Symptom | Diagnosis | Fix |
|---------|-----------|-----|
| Comment not posted/deleted | Missing permission | Add `permissions: pull-requests: write` to the job |
| Comment not found for deletion | Different header | Ensure `comment-header` matches between deploy and cleanup actions (default: `## 🚀 Preview Deployment`) |

### Retry configuration (deploy/cleanup/scheduled-cleanup)

| Symptom | Diagnosis | Fix |
|---------|-----------|-----|
| Retries exhausted but API was briefly down | Default 3 retries may not be enough | Increase `max-retries` (e.g., `5`) |
| Backoff too aggressive | Default starts at 2s, doubles each time | Increase `retry-delay` for longer waits |
| Want to disable retries | Some CI setups prefer fast failure | Set `max-retries: '0'` |

### Scheduled-cleanup specific issues

| Symptom | Diagnosis | Fix |
|---------|-----------|-----|
| All environments marked as stale | Date parsing may have failed (check warnings) | Verify `updated_at` field exists on environments |
| PR number extraction fails | `pr-number-pattern` doesn't match environment naming | Check `environment-pattern` and `pr-number-pattern` match your naming convention |
| GitHub API rate limit hit | Too many environments being checked | Action includes 0.5s delay between checks. For 1000+ environments, run less frequently |
| Overlapping cleanup runs | No concurrency guard | Add `concurrency: { group: scheduled-cleanup, cancel-in-progress: false }` to workflow |

### Token confusion guide

ZAD Actions use up to 3 different tokens:

| Input | Purpose | Default | When to customize |
|-------|---------|---------|-------------------|
| `api-key` | ZAD Operations Manager API auth | none (required) | Always set as `${{ secrets.ZAD_API_KEY }}` |
| `github-token` | PR comments, deployment deletion, container deletion | `${{ github.token }}` | Only when you need cross-repo access (use a PAT) |
| `github-admin-token` | Environment deletion | none (optional) | Required only for `delete-github-env: true`. Must be a PAT with `repo` scope |

## ZAD API docs

Full API documentation: `https://operations-manager.rig.prd1.gn2.quattro.rijksapps.nl/docs`

## General debugging steps

1. **Read the full error message** in the GitHub Actions log — the actions output specific `::error::` annotations
2. **Check the HTTP status code** — each code has a specific meaning (see table above)
3. **Verify secrets are set** — go to repo Settings > Secrets and variables > Actions
4. **Check permissions block** — ensure the job has the right `permissions:` entries
5. **Test API connectivity** — the ZAD API URL should be reachable from GitHub-hosted runners
