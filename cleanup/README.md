# Cleanup ZAD Deployment

Removes a ZAD deployment and optionally cleans up associated GitHub resources (environments, deployments, container images).

## Inputs

| Name | Required | Default | Description |
|------|----------|---------|-------------|
| `api-key` | Yes | - | ZAD API key (`ZAD_API_KEY` secret) |
| `project-id` | Yes | - | ZAD project identifier |
| `deployment-name` | Yes | - | Name of the deployment to delete |
| `delete-github-env` | No | `false` | Delete the GitHub environment (requires `github-admin-token`) |
| `delete-github-deployments` | No | `false` | Delete GitHub deployments for this environment (requires `github-token`) |
| `delete-container` | No | `false` | Delete the container image from GHCR |
| `container-org` | No | `''` | Organization owning the container (for image deletion) |
| `container-name` | No | `''` | Container package name (for image deletion) |
| `container-tag` | No | `''` | Container tag to delete (for image deletion) |
| `github-token` | No | `github.token` | GitHub token for deployments/containers/PR (defaults to automatic token) |
| `github-admin-token` | No | `''` | GitHub token for environment deletion (needs repo admin permission) |
| `api-base-url` | No | `https://operations-manager.rig.prd1.gn2.quattro.rijksapps.nl/api` | ZAD Operations Manager API base URL |
| `delete-pr-comment` | No | `true` | Delete the deploy PR comment |
| `comment-header` | No | `## 🚀 Preview Deployment` | Header of the deploy comment to find and delete |
| `skip-bot-prs` | No | `true` | Skip cleanup for PRs created by bots (dependabot, renovate, pre-commit-ci, etc.) |

## Outputs

| Name                         | Description                                              |
|------------------------------|----------------------------------------------------------|
| `zad-deleted`                | Whether the ZAD deployment was deleted (`true`/`false`)  |
| `github-env-deleted`         | Whether the GitHub environment was deleted               |
| `github-deployments-deleted` | Whether GitHub deployments were deleted                  |
| `container-deleted`          | Whether the container image was deleted                  |
| `pr-comment-deleted`         | Whether the PR comment was deleted                       |
| `skipped`                    | Whether cleanup was skipped due to bot PR detection      |

## Example Usage

### Basic ZAD Cleanup Only

```yaml
- name: Cleanup ZAD deployment
  uses: RijksICTGilde/zad-actions/cleanup@v2
  with:
    api-key: ${{ secrets.ZAD_API_KEY }}
    project-id: regel-k4c
    deployment-name: pr73
```

### Full Cleanup (ZAD + GitHub + Container)

```yaml
- name: Full cleanup
  uses: RijksICTGilde/zad-actions/cleanup@v2
  with:
    api-key: ${{ secrets.ZAD_API_KEY }}
    project-id: regel-k4c
    deployment-name: pr${{ github.event.pull_request.number }}
    delete-github-env: true
    delete-github-deployments: true
    delete-container: true
    container-org: minbzk
    container-name: regelrecht-mvp
    container-tag: pr-${{ github.event.number }}
    github-admin-token: ${{ secrets.GITHUB_ADMIN_TOKEN }}
```

### PR Closed Cleanup Workflow

```yaml
cleanup-preview:
  if: github.event_name == 'pull_request' && github.event.action == 'closed'
  runs-on: ubuntu-latest
  permissions:
    deployments: write
    packages: write
    pull-requests: write  # For delete-pr-comment
  steps:
    - name: Cleanup PR preview
      uses: RijksICTGilde/zad-actions/cleanup@v2
      with:
        api-key: ${{ secrets.ZAD_API_KEY }}
        project-id: my-project
        deployment-name: pr${{ github.event.pull_request.number }}
        delete-github-env: true
        delete-github-deployments: true
        delete-container: true
        container-org: ${{ github.repository_owner }}
        container-name: ${{ github.event.repository.name }}
        container-tag: pr-${{ github.event.number }}
        github-admin-token: ${{ secrets.GITHUB_ADMIN_TOKEN }}
        delete-pr-comment: true
```

### Delete PR Comment

When used with the deploy action's `comment-on-pr` feature, the cleanup action can remove the PR comment when the deployment is cleaned up:

```yaml
- uses: RijksICTGilde/zad-actions/cleanup@v2
  with:
    api-key: ${{ secrets.ZAD_API_KEY }}
    project-id: my-project
    deployment-name: pr${{ github.event.pull_request.number }}
    delete-pr-comment: true
    github-token: ${{ secrets.GITHUB_TOKEN }}
```

The action finds the deploy comment by its header (`## 🚀 Preview Deployment` by default) and deletes it.

## Permissions

### Required Workflow Permissions

```yaml
permissions:
  deployments: write   # For delete-github-deployments
  packages: write      # For delete-container
  pull-requests: write # For delete-pr-comment
```

### Token Requirements

| Operation | Token | Permission Required |
|-----------|-------|---------------------|
| Delete ZAD deployment | (API key only) | - |
| Delete GitHub deployments | `github-token` | `deployments: write` |
| Delete GitHub environment | `github-admin-token` | Repository admin access |
| Delete container image | `github-token` | `packages: delete` |
| Delete PR comment | `github-token` | `pull-requests: write` |

**Note:** The default `GITHUB_TOKEN` cannot delete GitHub environments. You need a Personal Access Token (PAT) or GitHub App token with admin permissions for the repository.

### Scheduled Stale Environment Cleanup

Automatically clean up old PR preview environments:

```yaml
name: Cleanup Stale Environments

on:
  schedule:
    - cron: '0 2 * * *'  # Daily at 2 AM
  workflow_dispatch:

jobs:
  cleanup-stale:
    runs-on: ubuntu-latest
    permissions:
      deployments: write
      packages: write
    steps:
      - name: Get stale PR environments
        id: stale
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          # Find PR environments older than 7 days
          gh api repos/${{ github.repository }}/environments \
            --jq '.environments[] | select(.name | startswith("pr")) | .name' > envs.txt
          echo "Found environments:"
          cat envs.txt

      - name: Cleanup each stale environment
        env:
          ZAD_API_KEY: ${{ secrets.ZAD_API_KEY }}
        run: |
          while read -r env; do
            echo "Cleaning up: $env"
            # Extract PR number from environment name (e.g., pr123 -> 123)
            pr_num="${env#pr}"
            # Add your cleanup logic here
          done < envs.txt
```

### Conditional Cleanup Based on Outputs

Check cleanup results and take action:

```yaml
- name: Cleanup deployment
  id: cleanup
  uses: RijksICTGilde/zad-actions/cleanup@v2
  with:
    api-key: ${{ secrets.ZAD_API_KEY }}
    project-id: my-project
    deployment-name: pr${{ github.event.pull_request.number }}
    delete-github-env: true
    delete-container: true
    container-org: ${{ github.repository_owner }}
    container-name: my-app
    container-tag: pr-${{ github.event.number }}
    github-admin-token: ${{ secrets.GITHUB_ADMIN_TOKEN }}

- name: Report cleanup results
  run: |
    echo "ZAD deleted: ${{ steps.cleanup.outputs.zad-deleted }}"
    echo "Environment deleted: ${{ steps.cleanup.outputs.github-env-deleted }}"
    echo "Container deleted: ${{ steps.cleanup.outputs.container-deleted }}"

- name: Notify on incomplete cleanup
  if: steps.cleanup.outputs.zad-deleted != 'true'
  run: echo "::warning::ZAD deployment was not deleted - may need manual cleanup"
```

## How It Works

1. **Delete ZAD Deployment**: Calls the ZAD Operations Manager DELETE API
2. **Delete GitHub Deployments** (optional): Marks all deployments for the environment as inactive, then deletes them
3. **Delete GitHub Environment** (optional): Deletes the GitHub environment
4. **Delete Container Image** (optional): Finds and deletes the container version with the specified tag
5. **Delete PR Comment** (optional): Removes the deploy comment from the PR

Each step runs independently and won't fail the action if it fails (cleanup is best-effort). Check the outputs to see what was actually deleted.

## Setting Up GITHUB_ADMIN_TOKEN

To delete GitHub environments, you need a token with admin permissions:

1. Create a Personal Access Token (classic) with `repo` scope, or
2. Use a GitHub App token with repository administration permissions

Store this as `GITHUB_ADMIN_TOKEN` in your repository secrets.
