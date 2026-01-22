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
| `github-token` | No | `''` | GitHub token for deployment and container deletion (`deployments: write`, `packages: delete`) |
| `github-admin-token` | No | `''` | GitHub token for environment deletion (needs repo admin permission) |
| `api-base-url` | No | `https://operations-manager.rig.prd1.gn2.quattro.rijksapps.nl/api` | ZAD Operations Manager API base URL |

## Outputs

| Name | Description |
|------|-------------|
| `zad-deleted` | Whether the ZAD deployment was deleted (`true`/`false`) |
| `github-env-deleted` | Whether the GitHub environment was deleted (`true`/`false`) |
| `github-deployments-deleted` | Whether GitHub deployments were deleted (`true`/`false`) |
| `container-deleted` | Whether the container image was deleted (`true`/`false`) |

## Example Usage

### Basic ZAD Cleanup Only

```yaml
- name: Cleanup ZAD deployment
  uses: RijksICTGilde/zad-actions/cleanup@v1
  with:
    api-key: ${{ secrets.ZAD_API_KEY }}
    project-id: regel-k4c
    deployment-name: pr73
```

### Full Cleanup (ZAD + GitHub + Container)

```yaml
- name: Full cleanup
  uses: RijksICTGilde/zad-actions/cleanup@v1
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
    github-token: ${{ secrets.GITHUB_TOKEN }}
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
  steps:
    - name: Cleanup PR preview
      uses: RijksICTGilde/zad-actions/cleanup@v1
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
        github-token: ${{ secrets.GITHUB_TOKEN }}
        github-admin-token: ${{ secrets.GITHUB_ADMIN_TOKEN }}
```

## Permissions

### Required Workflow Permissions

```yaml
permissions:
  deployments: write  # For delete-github-deployments
  packages: write     # For delete-container
```

### Token Requirements

| Operation | Token | Permission Required |
|-----------|-------|---------------------|
| Delete ZAD deployment | (API key only) | - |
| Delete GitHub deployments | `github-token` | `deployments: write` |
| Delete GitHub environment | `github-admin-token` | Repository admin access |
| Delete container image | `github-token` | `packages: delete` |

**Note:** The default `GITHUB_TOKEN` cannot delete GitHub environments. You need a Personal Access Token (PAT) or GitHub App token with admin permissions for the repository.

## How It Works

1. **Delete ZAD Deployment**: Calls the ZAD Operations Manager DELETE API
2. **Delete GitHub Deployments** (optional): Marks all deployments for the environment as inactive, then deletes them
3. **Delete GitHub Environment** (optional): Deletes the GitHub environment
4. **Delete Container Image** (optional): Finds and deletes the container version with the specified tag

Each step runs independently and won't fail the action if it fails (cleanup is best-effort). Check the outputs to see what was actually deleted.

## Setting Up GITHUB_ADMIN_TOKEN

To delete GitHub environments, you need a token with admin permissions:

1. Create a Personal Access Token (classic) with `repo` scope, or
2. Use a GitHub App token with repository administration permissions

Store this as `GITHUB_ADMIN_TOKEN` in your repository secrets.
