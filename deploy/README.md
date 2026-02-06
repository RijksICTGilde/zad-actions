# Deploy to ZAD

Deploys a container image to ZAD Operations Manager.

## Inputs

| Name | Required | Default | Description |
|------|----------|---------|-------------|
| `api-key` | Yes | - | ZAD API key (`ZAD_API_KEY` secret) |
| `project-id` | Yes | - | ZAD project identifier (e.g., `regel-k4c`) |
| `deployment-name` | Yes | - | Name of the deployment (e.g., `pr-73`, `production`) |
| `component` | Yes | - | Component reference (e.g., `editor`, `api`, `my.service`) |
| `image` | Yes | - | Full container image URI (e.g., `ghcr.io/org/app:tag`) |
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

## Outputs

| Name  | Description                     |
|-------|---------------------------------|
| `url` | URL of the deployed application |

## Example Usage

### Basic Deployment

```yaml
- name: Deploy to ZAD
  uses: RijksICTGilde/zad-actions/deploy@v2
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
  uses: RijksICTGilde/zad-actions/deploy@v2
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
      uses: RijksICTGilde/zad-actions/deploy@v2
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

> ## 🚀 Preview Deployment
>
> Your changes have been deployed to a preview environment:
>
> **URL:** https://web-pr85-my-project.your-domain.example.com
>
> This deployment will be automatically cleaned up when the PR is closed.

To include a text-based QR code for easy mobile access, set `qr-code: true`:

```yaml
comment-on-pr: true
qr-code: true
```

The QR code is generated locally using `qrencode` (no external dependencies), and appears in a collapsible section in the PR comment.

On subsequent deployments to the same PR, the existing comment is updated instead of creating a new one.

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
      uses: RijksICTGilde/zad-actions/deploy@v2
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

## URL Pattern

The output URL follows the standard ZAD pattern:
```
https://{component}-{deployment}-{project}.your-domain.example.com
```

For example:
- `component: web`, `deployment: pr85`, `project: my-project`
- URL: `https://web-pr85-my-project.your-domain.example.com`

### Multi-Component Deployment

Deploy multiple components in the same workflow:

```yaml
deploy:
  runs-on: ubuntu-latest
  strategy:
    matrix:
      component: [frontend, api, worker]
  steps:
    - name: Deploy ${{ matrix.component }}
      uses: RijksICTGilde/zad-actions/deploy@v2
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
      uses: RijksICTGilde/zad-actions/deploy@v2
      with:
        api-key: ${{ secrets.ZAD_API_KEY }}
        project-id: my-project
        deployment-name: staging
        component: web
        image: ghcr.io/org/app:${{ github.sha }}

    - name: Deploy to production
      if: github.ref == 'refs/heads/main'
      uses: RijksICTGilde/zad-actions/deploy@v2
      with:
        api-key: ${{ secrets.ZAD_API_KEY }}
        project-id: my-project
        deployment-name: production
        component: web
        image: ghcr.io/org/app:${{ github.sha }}
```

### Deploy with Deployment Status Check

Wait for deployment to be healthy using the built-in `wait-for-ready` feature:

```yaml
- name: Deploy to ZAD
  uses: RijksICTGilde/zad-actions/deploy@v2
  with:
    api-key: ${{ secrets.ZAD_API_KEY }}
    project-id: my-project
    deployment-name: production
    component: web
    image: ghcr.io/org/app:latest
    wait-for-ready: true
    health-endpoint: /health
```

## How It Works

1. Constructs a JSON payload with deployment configuration
2. Calls the ZAD Operations Manager upsert-deployment API
3. Returns the constructed URL as an output

If `clone-from` is specified, the new deployment will inherit configuration from the specified existing deployment. Use `force-clone: true` to re-clone configuration even if the deployment already exists.
