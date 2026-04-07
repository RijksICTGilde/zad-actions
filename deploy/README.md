# Deploy to ZAD

Deploys a container image to ZAD Operations Manager.

## Inputs

| Name | Required | Default | Description |
|------|----------|---------|-------------|
| `api-key` | Yes | - | ZAD API key (`ZAD_API_KEY` secret) |
| `project-id` | Yes | - | ZAD project identifier (e.g., `regel-k4c`) |
| `deployment-name` | Yes | - | Name of the deployment (e.g., `pr-73`, `production`) |
| `component` | No | `''` | Component reference (e.g., `editor`, `api`). Ignored when `components` is set. |
| `image` | No | `''` | Full container image URI (e.g., `ghcr.io/org/app:tag`). Ignored when `components` is set. |
| `components` | No | `''` | JSON array of components: `[{"name": "web", "image": "ghcr.io/org/app:tag"}]`. Takes precedence over `component`/`image`. |
| `clone-from` | No | `''` | Clone configuration from existing deployment |
| `force-clone` | No | `false` | Force clone even if deployment already exists |
| `api-base-url` | No | `https://operations-manager.rig.prd1.gn2.quattro.rijksapps.nl/api` | ZAD Operations Manager API base URL |
| `comment-on-pr` | No | `false` | Post/update a comment on the PR with the deployment URL |
| `github-token` | No | `github.token` | GitHub token for PR commenting (defaults to automatic token) |
| `comment-header` | No | `## 🚀 Preview Deployment` | Custom header for the PR comment |
| `wait-for-ready` | No | `false` | Wait for deployment to be reachable |
| `health-endpoint` | No | `/` | Endpoint to check for readiness |
| `wait-timeout` | No | `300` | Maximum wait time in seconds |
| `wait-interval` | No | `10` | Seconds between readiness checks |
| `qr-code` | No | `false` | Include QR code for mobile access (generated locally via qrencode) |
| `skip-bot-prs` | No | `true` | Skip deployment for PRs created by bots (dependabot, renovate, pre-commit-ci, etc.) |
| `max-retries` | No | `3` | Maximum number of retries for transient API errors (0 to disable) |
| `retry-delay` | No | `2` | Initial retry delay in seconds (doubles each retry) |
| `task-timeout` | No | `300` | Maximum time in seconds to wait for async task completion |
| `task-poll-interval` | No | `3` | Seconds between task status polls |
| `path-suffix` | No | `''` | Path to append to the deployment URL (e.g. `/docs/`) |
| `domain-format` | No | `''` | URL format template ID for hostname generation (see [Domain Configuration](#domain-configuration)) |
| `subdomain` | No | `''` | Subdomain for URL generation. Required when `domain-format` contains "subdomain" |
| `base-domain` | No | `''` | Base domain for URL generation (e.g., `rijksapp.nl`). Must be cluster-supported |

## Outputs

| Name      | Description                                           |
|-----------|-------------------------------------------------------|
| `url`     | URL of the deployed application (first component when using `components` input) |
| `urls`    | JSON object mapping component names to URLs (only set when using `components` input) |
| `skipped` | Whether deployment was skipped due to bot PR detection |

## Example Usage

### Basic Deployment

```yaml
- name: Deploy to ZAD
  uses: RijksICTGilde/zad-actions/deploy@v4
  with:
    api-key: ${{ secrets.ZAD_API_KEY }}
    project-id: my-project
    deployment-name: production
    component: web
    image: ghcr.io/org/app:latest
```

### PR Preview with Cloned Config

```yaml
- name: Deploy PR Preview
  id: deploy
  uses: RijksICTGilde/zad-actions/deploy@v4
  with:
    api-key: ${{ secrets.ZAD_API_KEY }}
    project-id: my-project
    deployment-name: pr${{ github.event.pull_request.number }}
    component: web
    image: ghcr.io/org/app:${{ github.sha }}
    clone-from: development
```

### PR Preview with Automatic Comment

Automatically post a comment on the PR with the deployment URL:

```yaml
deploy-preview:
  runs-on: ubuntu-latest
  if: github.event_name == 'pull_request'
  permissions:
    pull-requests: write
  steps:
    - name: Deploy PR Preview
      uses: RijksICTGilde/zad-actions/deploy@v4
      with:
        api-key: ${{ secrets.ZAD_API_KEY }}
        project-id: my-project
        deployment-name: pr${{ github.event.pull_request.number }}
        component: web
        image: ghcr.io/org/app:${{ github.sha }}
        clone-from: development
        comment-on-pr: true
```

The action will create a comment like this on the PR:

> ## 🚀 Preview Deployment — web
>
> Your changes have been deployed to a preview environment:
>
> **URL:** https://web-pr85-my-project.your-domain.example.com
>
> This deployment will be automatically cleaned up when the PR is closed.

When deploying multiple components (e.g. via matrix strategy), each component gets its own comment:

> ## 🚀 Preview Deployment — api
>
> Your changes have been deployed to a preview environment:
>
> **URL:** https://api-pr85-my-project.your-domain.example.com
>
> This deployment will be automatically cleaned up when the PR is closed.

To include a text-based QR code for easy mobile access, set `qr-code: true`:

```yaml
comment-on-pr: true
qr-code: true
```

The QR code is generated locally using `qrencode` (no external dependencies), and appears in a collapsible section in the PR comment.

On subsequent deployments to the same PR, each component's comment is updated individually. The cleanup action removes all component comments when the PR is closed.

### Use with GitHub Environment

```yaml
deploy:
  runs-on: ubuntu-latest
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
        image: ghcr.io/org/app:${{ github.sha }}
```

## Permissions

| Feature          | Required Permission       |
|------------------|---------------------------|
| Basic deployment | None (only ZAD API key)   |
| PR commenting    | `pull-requests: write`    |

For PR commenting, ensure your job has the required permission (the token defaults to `github.token`):

```yaml
permissions:
  pull-requests: write
```

## Domain Configuration

Control how deployment hostnames are generated using the optional `domain-format`, `subdomain`, and `base-domain` inputs.

### Domain Format Options

Dash-separated formats:

| Format | Example hostname |
|--------|-----------------|
| `component-deployment-project` | `web-pr85-my-project.base.domain` |
| `deployment-project` | `pr85-my-project.base.domain` |
| `component-deployment-subdomain` | `web-pr85-myapp.base.domain` |
| `deployment-subdomain` | `pr85-myapp.base.domain` |
| `component-subdomain` | `web-myapp.base.domain` |
| `subdomain` | `myapp.base.domain` |

Dot-separated formats:

| Format | Example hostname |
|--------|-----------------|
| `component.deployment.project` | `web.pr85.my-project.base.domain` |
| `deployment.project` | `pr85.my-project.base.domain` |
| `component.deployment.subdomain` | `web.pr85.myapp.base.domain` |
| `deployment.subdomain` | `pr85.myapp.base.domain` |
| `component.subdomain` | `web.myapp.base.domain` |

Formats containing `subdomain` require the `subdomain` input to be set.

### Example

```yaml
- name: Deploy with custom domain
  uses: RijksICTGilde/zad-actions/deploy@v4
  with:
    api-key: ${{ secrets.ZAD_API_KEY }}
    project-id: my-project
    deployment-name: production
    component: frontend
    image: ghcr.io/org/app:latest
    domain-format: component-deployment-subdomain
    subdomain: myapp
    base-domain: rijksapp.nl
```

## URL Pattern

When no domain configuration is specified, the output URL follows the default ZAD pattern:
```
https://{component}-{deployment}-{project}.your-domain.example.com
```

For example:
- `component: web`, `deployment: pr85`, `project: my-project`
- URL: `https://web-pr85-my-project.your-domain.example.com`

### Multi-Component Deployment (Single Step)

Deploy multiple components in a single action invocation:

```yaml
- name: Deploy all components
  uses: RijksICTGilde/zad-actions/deploy@v4
  with:
    api-key: ${{ secrets.ZAD_API_KEY }}
    project-id: my-project
    deployment-name: pr${{ github.event.pull_request.number }}
    components: |
      [
        {"name": "frontend", "image": "ghcr.io/org/frontend:${{ github.sha }}"},
        {"name": "api", "image": "ghcr.io/org/api:${{ github.sha }}"}
      ]
    clone-from: production
    comment-on-pr: true
```

This creates a single PR comment listing all component URLs:

> ## 🚀 Preview Deployment
>
> Your changes have been deployed to a preview environment:
>
> **frontend:** https://frontend-pr85-my-project.your-domain.example.com
> **api:** https://api-pr85-my-project.your-domain.example.com
>
> This deployment will be automatically cleaned up when the PR is closed.

> **Tip:** Use `components` for deploying multiple components atomically in a single API call. This is especially important when using `clone-from`, since the clone is applied once per API call — matrix strategy would trigger separate clones per component.

### Multi-Component Deployment (Matrix Strategy)

Deploy multiple components using matrix strategy (separate jobs per component):

```yaml
deploy:
  runs-on: ubuntu-latest
  strategy:
    matrix:
      component: [frontend, api, worker]
  steps:
    - name: Deploy ${{ matrix.component }}
      uses: RijksICTGilde/zad-actions/deploy@v4
      with:
        api-key: ${{ secrets.ZAD_API_KEY }}
        project-id: my-project
        deployment-name: production
        component: ${{ matrix.component }}
        image: ghcr.io/org/app-${{ matrix.component }}:${{ github.sha }}
```

### Conditional Deployment (Branch-Based)

Deploy to different environments based on branch:

```yaml
deploy:
  runs-on: ubuntu-latest
  steps:
    - name: Deploy to preview
      if: github.ref == 'refs/heads/staging'
      uses: RijksICTGilde/zad-actions/deploy@v4
      with:
        api-key: ${{ secrets.ZAD_API_KEY }}
        project-id: my-project
        deployment-name: staging
        component: web
        image: ghcr.io/org/app:${{ github.sha }}

    - name: Deploy to production
      if: github.ref == 'refs/heads/main'
      uses: RijksICTGilde/zad-actions/deploy@v4
      with:
        api-key: ${{ secrets.ZAD_API_KEY }}
        project-id: my-project
        deployment-name: production
        component: web
        image: ghcr.io/org/app:${{ github.sha }}
```

### Deployment with Custom Path Suffix

If your application is served under a subpath (e.g. `/docs/`), use `path-suffix` to include it in the output URL, PR comment, and QR code:

```yaml
- name: Deploy to ZAD
  uses: RijksICTGilde/zad-actions/deploy@v4
  with:
    api-key: ${{ secrets.ZAD_API_KEY }}
    project-id: my-project
    deployment-name: production
    component: web
    image: ghcr.io/org/app:latest
    path-suffix: /docs/
```

This produces a URL like `https://web-production-my-project.your-domain.example.com/docs/`.

### Deploy with Deployment Status Check

Wait for deployment to be healthy using the built-in `wait-for-ready` feature:

```yaml
- name: Deploy to ZAD
  uses: RijksICTGilde/zad-actions/deploy@v4
  with:
    api-key: ${{ secrets.ZAD_API_KEY }}
    project-id: my-project
    deployment-name: production
    component: web
    image: ghcr.io/org/app:latest
    wait-for-ready: true
    health-endpoint: /health
```

## Retry Behavior

Only the ZAD API call is retried on transient errors. Other operations (PR commenting, QR code generation) are not retried.

| HTTP Code | Retries? | Reason |
|-----------|----------|--------|
| 000 | Yes | Network error / timeout |
| 429 | Yes | Rate limit |
| 500-504 | Yes | Server errors |
| 401, 403 | No | Authentication / authorization |
| 404 | No | Project not found |

Backoff is exponential: 2s → 4s → 8s (default). Set `max-retries: '0'` to disable.

## How It Works

1. Constructs a JSON payload with deployment configuration
2. Calls the ZAD Operations Manager V2 async API to submit the deployment task (with retry on transient errors)
3. Polls the task status until completion or timeout
4. Returns the constructed URL as an output

If `clone-from` is specified, the new deployment will inherit configuration from the specified existing deployment. Use `force-clone: true` to re-clone configuration even if the deployment already exists.
