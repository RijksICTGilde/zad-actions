---
name: generate-workflow
description: >-
  Genereer een GitHub Actions workflow voor een repo die zad-actions
  deploy/cleanup gebruikt. Gebruik bij 'workflow genereren', 'hoe gebruik ik
  zad-actions', 'setup zad', 'integratie', 'voorbeeld workflow'.
model: sonnet
allowed-tools:
  - Read(*)
---

# Generate ZAD Workflow

Generate a complete GitHub Actions workflow for a repository that uses zad-actions for deployment.

## Usage

```
/generate-workflow
```

Or with arguments: `/generate-workflow project-id=my-project component=web`

## Steps

1. **Gather project details.** Ask the user for (or accept as arguments):
   - `project-id` (required): ZAD project identifier (e.g., `regel-k4c`)
   - `component` (required): Component reference (e.g., `web`, `api`, `editor`)
   - `container-registry` (optional, default: `ghcr.io`): Container registry to use
   - `image-name` (optional, default: `${{ github.repository }}`): Docker image name
   - Features to enable (ask the user):
     - `wait-for-ready` — wait for deployment health check
     - `qr-code` — QR code in PR comment for mobile testing
     - `comment-on-pr` — post deployment URL as PR comment
     - `clone-from` — clone config from existing deployment (e.g., `production`)
     - `path-suffix` — append a path to the deployment URL (e.g., `/docs/`)
     - `production-deploy` — add production deploy job on push to main

   - `scheduled-cleanup` — add a weekly scheduled cleanup job for stale PR environments

2. **Read current action inputs** from `deploy/action.yml`, `cleanup/action.yml`, and `scheduled-cleanup/action.yml` to ensure generated workflow uses correct input names and defaults.

3. **Generate the workflow file** with the following structure:

```yaml
name: Deploy

on:
  pull_request:
    types: [opened, synchronize, reopened, closed]
  push:
    branches: [main]  # only if production-deploy enabled

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
    steps:
      - uses: actions/checkout@v6
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
    needs: build
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: write  # if comment-on-pr
    environment:
      name: pr-${{ github.event.pull_request.number }}
      url: ${{ steps.deploy.outputs.url }}
    steps:
      - name: Deploy to ZAD
        id: deploy
        uses: RijksICTGilde/zad-actions/deploy@v2
        with:
          api-key: ${{ secrets.ZAD_API_KEY }}
          project-id: <project-id>
          deployment-name: pr-${{ github.event.pull_request.number }}
          component: <component>
          image: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:pr-${{ github.event.number }}

  cleanup-preview:
    if: github.event_name == 'pull_request' && github.event.action == 'closed'
    runs-on: ubuntu-latest
    permissions:
      deployments: write
      packages: write
      pull-requests: write
    steps:
      - name: Cleanup
        uses: RijksICTGilde/zad-actions/cleanup@v2
        with:
          api-key: ${{ secrets.ZAD_API_KEY }}
          project-id: <project-id>
          deployment-name: pr-${{ github.event.pull_request.number }}
          delete-github-env: 'true'
          delete-github-deployments: 'true'
          delete-container: 'true'
          container-org: ${{ github.repository_owner }}
          container-name: ${{ github.event.repository.name }}
          container-tag: pr-${{ github.event.number }}
          github-admin-token: ${{ secrets.GITHUB_ADMIN_TOKEN }}
```

   If `scheduled-cleanup` is enabled, add a separate workflow or job:

```yaml
  scheduled-cleanup:
    if: github.event_name == 'schedule'
    runs-on: ubuntu-latest
    permissions:
      deployments: write
      packages: write
      pull-requests: read
    steps:
      - uses: RijksICTGilde/zad-actions/scheduled-cleanup@v2
        with:
          api-key: ${{ secrets.ZAD_API_KEY }}
          project-id: <project-id>
          delete-container: true
          container-org: ${{ github.repository_owner }}
          container-name: ${{ github.event.repository.name }}
          github-admin-token: ${{ secrets.GITHUB_ADMIN_TOKEN }}
```

   Add `concurrency: { group: scheduled-cleanup, cancel-in-progress: false }` when scheduled-cleanup is included.

4. **Add inline YAML comments** explaining:
   - Why each `permissions:` block is needed
   - What each secret is for
   - What optional features do

5. **List required secrets** the user must configure:
   - `ZAD_API_KEY` (always required) — ZAD Operations Manager API key
   - `GITHUB_ADMIN_TOKEN` (if `delete-github-env` is used) — PAT with repo admin permissions

6. **Output the workflow** as a code block the user can copy, or write directly to `.github/workflows/deploy.yml` if the user confirms.

## Important notes

- Always use `@v2` for zad-actions references (current major version)
- The `github-token` input defaults to `${{ github.token }}` so it doesn't need to be passed explicitly
- `pull-requests: write` permission is needed for `comment-on-pr` and `delete-pr-comment`
- `packages: delete` permission is needed for container deletion (note: different from `packages: write`)
- ZAD URL pattern: `https://{component}-{deployment}-{project}.rig.prd1.gn2.quattro.rijksapps.nl`
- Bot PRs (dependabot, renovate, pre-commit-ci, github-actions) are skipped by default. Add `skip-bot-prs: 'false'` to deploy/cleanup if the user wants bot PR deployments
