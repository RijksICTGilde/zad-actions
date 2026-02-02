# ZAD Actions

GitHub Actions for deploying to ZAD (Zelfservice voor Applicatie Deployment) at Rijks ICT Gilde.

## Tech Stack

- **GitHub Actions**: Composite actions (`runs.using: composite`)
- **Bash**: Scripts in action steps
- **curl**: ZAD API calls
- **gh CLI**: GitHub API interactions

## Workflow

1. Edit `action.yml` files
2. Run `pre-commit run --all-files`
3. Update README.md if inputs/outputs changed
4. Update CHANGELOG.md
5. Create PR with conventional commit

## Versioning

- `v1.0.0` - exact version
- `v1` - major tag (users reference this)
