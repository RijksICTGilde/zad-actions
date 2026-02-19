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
  uses: RijksICTGilde/zad-actions/deploy@v2
  with:
    api-key: ${{ secrets.ZAD_API_KEY }}
    project-id: my-project
    deployment-name: my-deployment
    component: web
    image: ghcr.io/org/app:latest
```

### Cleanup

```yaml
- name: Cleanup ZAD deployment
  uses: RijksICTGilde/zad-actions/cleanup@v2
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

## Authentication

### ZAD API Key

Create a ZAD API key via the Operations Manager and store it as `ZAD_API_KEY` in your repository secrets.

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
        uses: RijksICTGilde/zad-actions/deploy@v2
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
        uses: RijksICTGilde/zad-actions/deploy@v2
        with:
          api-key: ${{ secrets.ZAD_API_KEY }}
          project-id: my-project
          deployment-name: production
          component: web
          image: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:latest
```

## ZAD Operations Manager API

These actions use the ZAD Operations Manager API:

- **Base URL**: `https://operations-manager.rig.prd1.gn2.quattro.rijksapps.nl/api`
- **API Docs**: `https://operations-manager.rig.prd1.gn2.quattro.rijksapps.nl/docs`

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
