# ZAD Actions

GitHub Actions for deploying to ZAD (Zelfservice voor Applicatie Deployment) at Rijks ICT Gilde.

## Actions

- `deploy/` — Deploy a container image to ZAD
- `cleanup/` — Remove a ZAD deployment and GitHub resources
- `scheduled-cleanup/` — Periodically find and clean up stale PR environments

## Tech Stack

- **GitHub Actions**: Composite actions (`runs.using: composite`)
- **Bash**: Scripts in action steps (shared `curl_with_retry` pattern for ZAD API calls)
- **curl**: ZAD API calls (with retry on transient errors)
- **gh CLI**: GitHub API interactions (best-effort, no retry)

## Workflow

1. Edit `action.yml` files
2. Run `pre-commit run --all-files`
3. Update README.md if inputs/outputs changed
4. Update CHANGELOG.md
5. Create PR with conventional commit

## Versioning

- `v1.0.0` - exact version
- `v1` - major tag (users reference this)
