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

## Outputs

| Name | Description |
|------|-------------|
| `url` | URL of the deployed application |

## Example Usage

### Basic Deployment

```yaml
- name: Deploy to ZAD
  id: deploy
  uses: RijksICTGilde/zad-actions/deploy@v1
  with:
    api-key: ${{ secrets.ZAD_API_KEY }}
    project-id: regel-k4c
    deployment-name: production
    component: editor
    image: ghcr.io/minbzk/regelrecht-mvp:latest

- name: Show deployment URL
  run: echo "Deployed to ${{ steps.deploy.outputs.url }}"
```

### PR Preview with Cloned Config

```yaml
- name: Deploy PR Preview
  id: deploy
  uses: RijksICTGilde/zad-actions/deploy@v1
  with:
    api-key: ${{ secrets.ZAD_API_KEY }}
    project-id: regel-k4c
    deployment-name: pr${{ github.event.pull_request.number }}
    component: editor
    image: ghcr.io/minbzk/regelrecht-mvp:pr-${{ github.event.number }}
    clone-from: production
```

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
      uses: RijksICTGilde/zad-actions/deploy@v1
      with:
        api-key: ${{ secrets.ZAD_API_KEY }}
        project-id: my-project
        deployment-name: pr${{ github.event.pull_request.number }}
        component: web
        image: ghcr.io/org/app:pr-${{ github.event.number }}
```

## Permissions

This action requires no special GitHub permissions. Only the ZAD API key is needed.

## URL Pattern

The output URL follows the standard ZAD pattern:
```
https://{component}-{deployment}-{project}.rig.prd1.gn2.quattro.rijksapps.nl
```

For example:
- `component: editor`, `deployment: pr73`, `project: regel-k4c`
- URL: `https://editor-pr73-regel-k4c.rig.prd1.gn2.quattro.rijksapps.nl`

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
      uses: RijksICTGilde/zad-actions/deploy@v1
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
    - name: Deploy to staging
      if: github.ref == 'refs/heads/develop'
      uses: RijksICTGilde/zad-actions/deploy@v1
      with:
        api-key: ${{ secrets.ZAD_API_KEY }}
        project-id: my-project
        deployment-name: staging
        component: web
        image: ghcr.io/org/app:${{ github.sha }}

    - name: Deploy to production
      if: github.ref == 'refs/heads/main'
      uses: RijksICTGilde/zad-actions/deploy@v1
      with:
        api-key: ${{ secrets.ZAD_API_KEY }}
        project-id: my-project
        deployment-name: production
        component: web
        image: ghcr.io/org/app:${{ github.sha }}
        clone-from: staging
```

### Deploy with Deployment Status Check

Wait for deployment to be healthy:

```yaml
- name: Deploy to ZAD
  id: deploy
  uses: RijksICTGilde/zad-actions/deploy@v1
  with:
    api-key: ${{ secrets.ZAD_API_KEY }}
    project-id: my-project
    deployment-name: production
    component: web
    image: ghcr.io/org/app:latest

- name: Wait for deployment to be ready
  run: |
    for i in {1..30}; do
      if curl -s -o /dev/null -w "%{http_code}" "${{ steps.deploy.outputs.url }}/health" | grep -q "200"; then
        echo "Deployment is healthy!"
        exit 0
      fi
      echo "Waiting for deployment... (attempt $i/30)"
      sleep 10
    done
    echo "Deployment health check timed out"
    exit 1
```

## How It Works

1. Constructs a JSON payload with deployment configuration
2. Calls the ZAD Operations Manager upsert-deployment API
3. Returns the constructed URL as an output

If `clone-from` is specified, the new deployment will inherit configuration from the specified existing deployment. Use `force-clone: true` to re-clone configuration even if the deployment already exists.
