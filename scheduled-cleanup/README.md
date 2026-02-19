# Scheduled Cleanup of Stale PR Environments

Automatically finds and cleans up ZAD deployments for closed or merged PRs. Intended to run on a schedule (e.g., weekly) to catch environments that were missed by the normal PR-close cleanup.

## Inputs

| Name | Required | Default | Description |
|------|----------|---------|-------------|
| `api-key` | Yes | - | ZAD API key (`ZAD_API_KEY` secret) |
| `project-id` | Yes | - | ZAD project identifier |
| `environment-pattern` | No | `^pr-?[0-9]+$` | Regex pattern to match PR environments |
| `pr-number-pattern` | No | `s/^pr-\{0,1\}//` | Sed expression to extract PR number from environment name |
| `max-age-days` | No | `0` | Also cleanup environments older than N days regardless of PR state (0 to disable) |
| `dry-run` | No | `false` | List stale environments without deleting |
| `delete-github-env` | No | `true` | Delete the GitHub environment |
| `delete-github-deployments` | No | `true` | Delete GitHub deployments for each environment |
| `delete-container` | No | `false` | Delete the container image from GHCR |
| `container-org` | No | `''` | Organization owning the container |
| `container-name` | No | `''` | Container package name |
| `github-token` | No | `github.token` | GitHub token for API operations |
| `github-admin-token` | No | `''` | GitHub token for environment deletion (needs repo admin permission) |
| `api-base-url` | No | `https://operations-manager.rig.prd1.gn2.quattro.rijksapps.nl/api` | ZAD Operations Manager API base URL |
| `max-retries` | No | `3` | Maximum number of retries for transient API errors (0 to disable) |
| `retry-delay` | No | `2` | Initial retry delay in seconds (doubles each retry) |

## Outputs

| Name | Description |
|------|-------------|
| `stale-count` | Number of stale environments found |
| `cleaned-count` | Number of environments successfully cleaned |
| `stale-environments` | JSON array of stale environment names |

## Example Usage

### Weekly Cleanup

```yaml
name: Cleanup Stale Preview Environments
on:
  schedule:
    - cron: '0 2 * * 1'  # Weekly on Monday at 02:00
  workflow_dispatch:

jobs:
  cleanup:
    runs-on: ubuntu-latest
    permissions:
      deployments: write
      packages: write
      pull-requests: read
    steps:
      - uses: RijksICTGilde/zad-actions/scheduled-cleanup@v2
        with:
          api-key: ${{ secrets.ZAD_API_KEY }}
          project-id: my-project
          environment-pattern: '^pr-?[0-9]+$'
          delete-container: true
          container-org: my-org
          container-name: my-app
          github-admin-token: ${{ secrets.GITHUB_ADMIN_TOKEN }}
```

### Dry Run First

Test what would be cleaned up without actually deleting anything:

```yaml
- uses: RijksICTGilde/zad-actions/scheduled-cleanup@v2
  with:
    api-key: ${{ secrets.ZAD_API_KEY }}
    project-id: my-project
    dry-run: true
```

### Age-Based Cleanup

Clean up environments older than 30 days, even if the PR is still open:

```yaml
- uses: RijksICTGilde/zad-actions/scheduled-cleanup@v2
  with:
    api-key: ${{ secrets.ZAD_API_KEY }}
    project-id: my-project
    max-age-days: 30
```

### Custom Environment Naming

If your environments use a different naming convention (e.g., `preview-123`):

```yaml
- uses: RijksICTGilde/zad-actions/scheduled-cleanup@v2
  with:
    api-key: ${{ secrets.ZAD_API_KEY }}
    project-id: my-project
    environment-pattern: '^preview-[0-9]+$'
    pr-number-pattern: 's/^preview-//'
```

## How It Works

1. **Scan**: Fetches all GitHub environments for the repository (paginated)
2. **Filter**: Matches environment names against `environment-pattern`
3. **Check**: For each match, extracts the PR number and checks if the PR is still open
4. **Age check**: If `max-age-days` is set, also marks environments older than N days as stale
5. **Cleanup**: For each stale environment (unless `dry-run`):
   - Deletes the ZAD deployment (with retry on transient errors)
   - Deletes GitHub deployments (marks inactive, then deletes)
   - Deletes the GitHub environment (if `github-admin-token` provided)
   - Deletes the container image (if `delete-container` enabled)

## Permissions

```yaml
permissions:
  deployments: write    # For deleting GitHub deployments
  packages: write       # For deleting container images
  pull-requests: read   # For checking PR state
```

For environment deletion, a `github-admin-token` with repo admin access is required (the default `GITHUB_TOKEN` cannot delete environments).
