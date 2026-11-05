# ZAD Actions

[![CI](https://github.com/RijksICTGilde/zad-actions/actions/workflows/ci.yml/badge.svg)](https://github.com/RijksICTGilde/zad-actions/actions/workflows/ci.yml)
[![License: EUPL-1.2](https://img.shields.io/badge/License-EUPL--1.2-blue.svg)](https://opensource.org/licenses/EUPL-1.2)
[![GitHub release](https://img.shields.io/github/v/release/RijksICTGilde/zad-actions)](https://github.com/RijksICTGilde/zad-actions/releases)
[![Claude Code plugin](https://img.shields.io/badge/Claude_Code-plugin-blueviolet.svg)](https://github.com/MinBZK/overheid-claude-plugins)

Reusable GitHub Actions for deploying to [ZAD](https://github.com/RijksICTGilde/RIG-Cluster) (Zelfservice voor Applicatie Deployment).

## Available Actions

| Action | Description |
|--------|-------------|
| [deploy](./deploy) | Deploy a container image to ZAD |
| [cleanup](./cleanup) | Remove a ZAD deployment and optionally clean up GitHub resources |
| [scheduled-cleanup](./scheduled-cleanup) | Periodically find and clean up stale PR environments |

## Quick Start

### Deploy

```yaml
- name: Deploy to ZAD
  uses: RijksICTGilde/zad-actions/deploy@v4
  with:
    api-key: ${{ secrets.ZAD_API_KEY }}
    project-id: my-project
    deployment-name: my-deployment
    component: web
    image: ghcr.io/org/app:latest
```

### Deploy (Multi-Component)

```yaml
- name: Deploy to ZAD
  uses: RijksICTGilde/zad-actions/deploy@v4
  with:
    api-key: ${{ secrets.ZAD_API_KEY }}
    project-id: my-project
    deployment-name: my-deployment
    components: |
      [
        {"name": "web", "image": "ghcr.io/org/web:latest"},
        {"name": "api", "image": "ghcr.io/org/api:latest"}
      ]
```

### Cleanup

```yaml
- name: Cleanup ZAD deployment
  uses: RijksICTGilde/zad-actions/cleanup@v4
  with:
    api-key: ${{ secrets.ZAD_API_KEY }}
    project-id: my-project
    deployment-name: my-deployment
    delete-github-env: true
    delete-github-deployments: true
    delete-container: true
    container-org: my-org
    container-name: my-app
    container-tag: pr-123
    github-token: ${{ secrets.GITHUB_TOKEN }}
    github-admin-token: ${{ secrets.GITHUB_ADMIN_TOKEN }}
```

### Cleanup (Multi-Container)

```yaml
- name: Cleanup ZAD deployment
  uses: RijksICTGilde/zad-actions/cleanup@v4
  with:
    api-key: ${{ secrets.ZAD_API_KEY }}
    project-id: my-project
    deployment-name: my-deployment
    delete-container: true
    containers: |
      [
        {"org": "my-org", "name": "frontend", "tag": "pr-123"},
        {"org": "my-org", "name": "api", "tag": "pr-123"}
      ]
```

### Scheduled Cleanup

```yaml
name: Cleanup Stale Environments
on:
  schedule:
    - cron: '0 2 * * 1'
concurrency:
  group: scheduled-cleanup
  cancel-in-progress: false
jobs:
  cleanup:
    runs-on: ubuntu-latest
    permissions:
      deployments: write
      packages: write
      pull-requests: read
    steps:
      - uses: RijksICTGilde/zad-actions/scheduled-cleanup@v4
        with:
          api-key: ${{ secrets.ZAD_API_KEY }}
          project-id: my-project
          github-admin-token: ${{ secrets.GITHUB_ADMIN_TOKEN }}
```

## Authentication

### ZAD API token

The `api-key` input takes an API token from the Operations Manager, stored as the `ZAD_API_KEY` repository secret. Tokens live on a project's **Team** tab, under **Leden en tokens**. A token belongs to a member of the project, a person or a service account, and may do what that member's roles allow. Changing the roles or removing the member applies to all of its tokens at once.

For a pipeline that deploys and cleans up PR environments:

1. Add a service account to the project and give it two roles: `Developer CI` and `Viewer`.
2. Make a token for that service account and store it as `ZAD_API_KEY` in your repository secrets. Only an `Admin` of the project can make a token for a service account.

`Developer CI` may create, update and delete deployments that are not on production, but it carries no read rights. The actions read back after every change: they wait on the task they started, read the deployment's URLs and check for changes that are not rolled out yet. Without `Viewer` those reads answer 403, and `deploy` fails even though the deployment went through.

With `Developer CI`, a redeploy of an existing deployment with `domain-format`, `subdomain` or `base-domain` set answers 403: changing the host name of an existing deployment is reserved for `Ops`. Set those inputs only for the first deploy, or leave them out.

To deploy to production with `deploy`, use a separate service account with `Ops`, and keep its token in a GitHub environment secret of the production environment. `Ops CI` does not work with these actions: it only replaces the image of a deployment, a call these actions do not make. A deployment on production cannot be deleted from a pipeline, because that needs the 2-factor confirmation of a person.

Do not use a token of a human member: it carries every role that person has, `Admin` included. Every token has an expiry date, 30 days by default. A token for a service account can be valid for 365 days at most, a personal token for 90. A 401 from a workflow that used to work usually means the token expired.

An API key from before tokens existed was turned into a token of the service account `project-api`, with the roles `Admin` and `Ops`. It keeps working, but it may do everything in the project; replace it with a service account as above.

### GitHub Tokens

For cleanup operations, different tokens are needed depending on what you want to clean up:

| Operation | Required Token | Permissions |
|-----------|---------------|-------------|
| Delete GitHub deployments | `github-token` | `deployments: write` |
| Delete GitHub environment | `github-admin-token` | Repository admin access |
| Delete container image | `github-token` | `packages: delete` |

The `github-admin-token` requires a personal access token (PAT) or GitHub App token with admin permissions on the repository. The default `GITHUB_TOKEN` does not have sufficient permissions to delete environments.

## Complete Workflow Example

Here's a complete example of a PR preview deployment workflow:

```yaml
name: Deploy

on:
  pull_request:
    types: [opened, synchronize, reopened, closed]
  push:
    branches: [main]

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  build:
    if: github.event.action != 'closed'
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
    outputs:
      image-tag: ${{ steps.meta.outputs.tags }}
    steps:
      - uses: actions/checkout@v4

      - name: Log in to GHCR
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Build and push
        uses: docker/build-push-action@v6
        with:
          context: .
          push: true
          tags: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:pr-${{ github.event.number }}

  deploy-preview:
    if: github.event_name == 'pull_request' && github.event.action != 'closed'
    runs-on: ubuntu-latest
    needs: build
    environment:
      name: pr${{ github.event.pull_request.number }}
      url: ${{ steps.deploy.outputs.url }}
    steps:
      - name: Deploy to ZAD
        id: deploy
        uses: RijksICTGilde/zad-actions/deploy@v4
        with:
          api-key: ${{ secrets.ZAD_API_KEY }}
          project-id: my-project
          deployment-name: pr${{ github.event.pull_request.number }}
          component: web
          image: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:pr-${{ github.event.number }}
          clone-from: production

  cleanup-preview:
    if: github.event_name == 'pull_request' && github.event.action == 'closed'
    runs-on: ubuntu-latest
    permissions:
      deployments: write
      packages: write
    steps:
      - name: Cleanup
        uses: RijksICTGilde/zad-actions/cleanup@v4
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

  deploy-production:
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    needs: build
    environment:
      name: production
      url: ${{ steps.deploy.outputs.url }}
    steps:
      - name: Deploy to ZAD
        id: deploy
        uses: RijksICTGilde/zad-actions/deploy@v4
        with:
          api-key: ${{ secrets.ZAD_API_KEY }}
          project-id: my-project
          deployment-name: production
          component: web
          image: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:latest
```

## ZAD Operations Manager API

These actions use [zad-cli](https://github.com/RijksICTGilde/zad-cli) to interact with the ZAD Operations Manager API. The CLI handles retries, task polling, and error reporting.

- **API Docs**: `https://operations-manager.rig.prd1.gn2.quattro.rijksapps.nl/docs`

### Other clusters

The actions use the production cluster by default. To use another ZAD cluster, such as staging at `https://zad.staging.rijksapp.dev`, set `api-base-url` to that cluster's API (its host followed by `/api`):

```yaml
- uses: RijksICTGilde/zad-actions/deploy@v4
  with:
    api-key: ${{ secrets.ZAD_STAGING_API_KEY }}
    project-id: my-project
    deployment-name: pr-${{ github.event.pull_request.number }}
    component: web
    image: ghcr.io/org/app:pr-${{ github.event.pull_request.number }}
    api-base-url: https://zad.staging.rijksapp.dev/api
```

Set the same `api-base-url` on `cleanup` and `scheduled-cleanup`, or they look for the deployment on production. Projects, and with them their members and tokens, exist per cluster: make the token in the Operations Manager of the cluster you deploy to.

### URL Pattern

Deployed applications are accessible at:
```
https://{component}-{deployment}-{project}.rig.prd1.gn2.quattro.rijksapps.nl
```

## Claude Code Plugin

This repository is also available as a [Claude Code](https://docs.anthropic.com/en/docs/claude-code) plugin via the [overheid-plugins marketplace](https://github.com/MinBZK/overheid-claude-plugins). It provides 3 skills to assist with development:

| Skill | Description |
|-------|-------------|
| `/zad-actions:lint` | Run pre-commit linting |
| `/zad-actions:release` | Create a new release with changelog extraction |
| `/zad-actions:validate-action` | Validate action.yml files for correctness |

### Install

```bash
claude plugin marketplace add MinBZK/overheid-claude-plugins
claude plugin install zad-actions@overheid-plugins
```

## Contributing

Contributions are welcome! Please open an issue or pull request.

## License

EUPL-1.2 - see [LICENSE](./LICENSE) for details.
