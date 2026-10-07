---
name: debug-deploy
description: "Diagnose falende ZAD deployments of cleanup actions. Gebruik bij 'deployment faalt', 'error', 'deploy werkt niet', 'cleanup faalt', 'HTTP error', '401', '403', '404'."
model: sonnet
allowed-tools:
  - Read(*)
  - Grep(*)
metadata:
  created-with-ai: "true"
  created-with-model: claude-opus-4-20250514
  created-date: "2025-02-16"
  status: concept
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

### Deployment hand-over (deploy)

A deployment task is superseded when a newer task covers its deployment scope: the same deployment deployed again, or a project-wide task such as a service or component change. It then *completes* with `status: superseded`, and the deploy step follows the reference to the task that took over, up to ten hand-overs in a row, before it reports anything. Two deploys of different deployments never supersede each other.

| Symptom | Diagnosis | Fix |
|---------|-----------|-----|
| `::notice::Deployment was handed over to task <id>` and the step still succeeds | Expected — another task took the rollout over and this step waited for that task to finish | None. Add a `concurrency` group to the workflow if you would rather deploys to one project did not overlap |
| `Deployment: task <id>, which took over, ended 'failed'` (or `'cancelled'`) | The task that took the rollout over never finished it, so the new image is not serving | Inspect that task id in Operations Manager and re-run the deploy. The `::error::` lines under it carry the CLI's diagnosis when the task result has one |
| `After the hand-over, N change(s) are saved but not rolled out.` | The task that took over saved its change to the project file without rolling it out, so the deployment's addresses are what the project asks for and not what is serving | Run `zad project refresh` for the project, then re-run the deploy |
| `Deployment: waiting for task <id>, which took over, failed` / `returned no usable JSON` | The wait on the taking-over task itself failed — timeout, auth, or an answer that is not JSON | Check the `::error::` lines under it for the cause. Raise `task-timeout` when the taking-over task legitimately needs longer |
| `Deployment was handed over 10 times without reaching a final task` | Tasks keep starting in the project, so the chain never reaches one that finishes | Stop the overlapping deploys (add a `concurrency` group) and inspect the project's tasks with `zad task list` |
| `Deployment was superseded but the result does not name the task that took over` / `the task that took over has an unusable task id` | There is nothing to wait for, so the rollout cannot be reported as finished | Re-run the deploy once the project is quiet. Report it if it repeats — the reference comes from the API |
| `::warning::Could not read how many changes are waiting to be rolled out` | `zad project pending` did not answer. The cause is in brackets when the CLI gave one; the one worth ruling out is an API key that lacks the right to list the project's pending changes | One-off: none, the step's own verdict stands. Persistent: check the key's access, otherwise a change that is saved but not rolled out stays unnoticed |

### Deployment readiness errors (wait-for-ready)

| Symptom | Diagnosis | Fix |
|---------|-----------|-----|
| Timeout waiting for deployment | Container not starting or slow startup | Increase `wait-timeout` (default: 300s). Check container logs in ZAD. Verify `health-endpoint` returns an accepted code (default `200-399`, `401`, `403`) |
| Timeout while the endpoint answers 4xx | Health endpoint returns a code outside the accepted set (e.g. `404` on the path, or a custom auth code) | Point `health-endpoint` at a path the app actually serves, or widen `health-status-codes` (e.g. `200-399,401,403,404`) |
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
| Container not found | Wrong org/name/tag | Verify `container-org`/`container-name`/`container-tag` (or `containers` JSON entries) match exactly. Tag format is typically `pr-<number>` |
| `Error: containers input is not valid JSON` | `containers` value is malformed JSON | Verify JSON syntax. Use YAML multi-line `\|` for readability. Validate with `echo '<json>' \| jq .` |
| `Error: containers array must contain at least one entry` | Empty array `[]` passed | Provide at least one `{"org": "...", "name": "...", "tag": "..."}` entry |
| `Error: each container must have non-empty 'org', 'name', and 'tag'` | Missing or empty fields in an array entry | Ensure every object has `org`, `name`, and `tag` keys with non-empty values |
| `Error: container org(s) contain invalid characters` | Org name has characters outside `a-zA-Z0-9._-` | Use only alphanumeric characters, dots, underscores, and hyphens |
| `Error: container name(s) contain invalid characters` | Container name has characters outside `a-zA-Z0-9._-` | Same character restrictions as org |
| `Error: container tag(s) contain dangerous characters` | Tag contains quotes, backticks, or backslashes | Remove these characters from the tag |

### PR comment errors

| Symptom | Diagnosis | Fix |
|---------|-----------|-----|
| Comment not posted/deleted | Missing permission | Add `permissions: pull-requests: write` to the job |
| Comment not found for deletion | Different header | Single-component uses `## 🚀 Preview Deployment — {component}`, multi-component uses `## 🚀 Preview Deployment`. Cleanup matches via `startswith()` so the base header covers both modes |

### Multi-component input errors (deploy)

| Symptom | Diagnosis | Fix |
|---------|-----------|-----|
| `Error: components input is not valid JSON` | `components` value is malformed JSON | Verify JSON syntax. Use YAML multi-line `\|` for readability. Validate with `echo '<json>' \| jq .` |
| `Error: components array must contain at least one entry` | Empty array `[]` passed | Provide at least one `{"name": "...", "image": "..."}` entry |
| `Error: each component must have a non-empty 'name' and 'image'` | Missing or empty fields in an array entry | Ensure every object has both `name` and `image` keys with non-empty values |
| `Error: component name(s) contain invalid characters` | Component name has characters outside `a-zA-Z0-9._-` | Use only alphanumeric characters, dots, underscores, and hyphens |
| `Error: either 'components' or both 'component' and 'image' must be provided` | Neither mode is configured | Provide either `components` JSON array OR both `component` and `image` inputs |
| `urls` output is empty | Using single-component mode | The `urls` output is only set when using the `components` input. In single-component mode, only `url` is set |

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
