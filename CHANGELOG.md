# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

### Added
- **deploy** action: New `path-suffix` input to append a path to the deployment URL (e.g. `/docs/`)
  - The suffix is included in the `url` output, PR comment, and QR code
  - Handles leading/trailing slashes gracefully

## [2.2.0] - 2026-02-19

### Added
- **deploy**, **cleanup**, and **scheduled-cleanup** actions: Retry with exponential backoff for transient ZAD API errors
  - New inputs: `max-retries` (default: `3`), `retry-delay` (default: `2`)
  - Retries on network errors (HTTP 000), rate limits (429), and server errors (500-504)
  - Does not retry on auth errors (401, 403) or not found (404)
  - Backoff: 2s → 4s → 8s (worst-case 14s extra)
  - Retry logic extracted into shared `curl_with_retry` bash function
  - Note: only ZAD API calls are retried; GitHub API calls use best-effort error handling
- **scheduled-cleanup** action: Periodically find and clean up stale PR environments
  - Scans GitHub environments matching a configurable regex pattern
  - Checks PR state and marks closed/merged PRs as stale
  - Optional age-based cleanup via `max-age-days`
  - Dry-run mode for safe testing
  - Cleans up ZAD deployments, GitHub deployments/environments, and container images
  - Smart rate limiting: reads `X-RateLimit-Remaining` header and only pauses when approaching the limit (replaces blind 0.5s delay)
  - Input validation for `environment-pattern` and `pr-number-pattern` (including sed `e` flag injection protection)
  - `cleaned-count` output defaults to `0` when no cleanup is needed
  - Compact JSON output for `stale-environments` to prevent GITHUB_OUTPUT corruption
  - Safe date parsing: warns and skips age check instead of falling back to epoch 0
  - Container deletion uses `2>/dev/null` instead of `2>&1` to prevent stderr leaking into captured output

### Changed
- **deploy**, **cleanup**: ZAD API calls now retry 3 times by default on transient errors (was 0).
  This adds up to 14s extra delay on persistent failures. Set `max-retries: '0'` to restore previous fail-fast behavior.
- **deploy**, **cleanup**: `github-token` default now consistently quoted as `'${{ github.token }}'`

### Fixed
- **scheduled-cleanup**: `cleaned-count` no longer counts 404 (already deleted) as successfully cleaned
- **scheduled-cleanup**: Admin token no longer leaks into subsequent operations if environment deletion fails (uses subshell)
- **scheduled-cleanup**: `pr-number-pattern` is now validated in both find-stale and cleanup steps (defense-in-depth)

## [2.1.0] - 2026-02-18

### Added
- **deploy** and **cleanup** actions: Skip bot PR deployments by default
  - New input: `skip-bot-prs` (default: `true`)
  - New output: `skipped`
  - Detects bots via GitHub user type and known bot list (dependabot, renovate, pre-commit-ci, github-actions)
  - Set `skip-bot-prs: 'false'` to restore previous behavior
  - Supports both `pull_request` and `pull_request_target` events

### Security
- CI workflow: Add explicit `permissions: contents: read` to all jobs to comply with GitHub security best practices

## [2.0.1] - 2026-02-06

### Fixed
- **deploy** QR code not displaying in PR comments (switched from base64 PNG to text-based UTF8 format)
- **cleanup** action: Handle deletion of last tagged package version by deleting entire package when needed

### Changed
- Update all documentation examples to use `@v2` instead of `@v1`
- SECURITY.md: Mark v1.x.x as end of life, v2.x.x as supported

## [2.0.0] - 2026-02-02

### Added
- **cleanup** action: PR comment delete feature
  - Delete the deploy PR comment when PR is closed (default: enabled)
  - New inputs: `delete-pr-comment`, `comment-header`
  - New output: `pr-comment-deleted`

### Removed
- **BREAKING** `cleanup` action: `update-pr-comment` input (use `delete-pr-comment` instead)
- **BREAKING** `cleanup` action: `pr-comment-updated` output (use `pr-comment-deleted` instead)

### Migration from v1

If you use the cleanup action with `update-pr-comment`, update your workflow:
- Replace `update-pr-comment: true` with `delete-pr-comment: true`
- The output `pr-comment-updated` is now `pr-comment-deleted`
- Note: `delete-pr-comment` defaults to `true`, so you can remove it if you want the comment deleted

## [1.3.0] - 2026-02-02

### Added
- **deploy** action: Wait for ready feature
  - Wait for deployment to be reachable before continuing
  - New inputs: `wait-for-ready`, `health-endpoint`, `wait-timeout`, `wait-interval`
  - Polls deployment URL until HTTP 2xx/3xx or timeout
  - PR comment only appears after deployment is healthy (when combined with `comment-on-pr`)
- **deploy** action: QR code in PR comment
  - New input: `qr-code` (default: `false`)
  - QR code for easy mobile testing of preview deployments
  - Generated locally using `qrencode` (no external API calls, privacy-friendly)
- `.editorconfig` for consistent editor formatting
- `.github/dependabot.yml` for automated GitHub Actions updates
- `.gitignore` for local settings and Claude plans
- `.claude/` configuration for AI assistant (coding rules, skills, workflow)

### Changed
- `.pre-commit-config.yaml`: require minimum version 4.5.0
- `CONTRIBUTING.md`: simplify setup with `uv` instead of `pip`
- `release.yml`: verify CHANGELOG entry exists, rollback tag on failure
- **deploy** and **cleanup** actions: `github-token` now defaults to `github.token`
  - No longer necessary to explicitly pass `github-token: ${{ secrets.GITHUB_TOKEN }}`
  - Only needed when using a custom PAT for cross-repository operations
- Bump `actions/checkout` from v4 to v6

### Internal
- Added justfile for common development tasks
- Added pre-commit.ci configuration (weekly autoupdates, skip duplicates with CI)

## [1.2.0] - 2026-01-22

### Added
- **cleanup** action: PR comment update feature
  - Update the deploy PR comment to show cleanup status when PR is closed
  - New inputs: `update-pr-comment`, `comment-header`
  - New output: `pr-comment-updated`

## [1.1.0] - 2026-01-22

### Added
- **deploy** action: PR commenting feature
  - Automatically post/update a comment on PRs with the deployment URL
  - New inputs: `comment-on-pr`, `github-token`, `comment-header`
  - Upsert behavior: updates existing comment instead of creating duplicates
- CI/CD pipeline with ShellCheck, actionlint, and yamllint
- Branch protection and governance files (CODEOWNERS, issue templates, PR template)
- CONTRIBUTING.md with development guidelines
- SECURITY.md with security policy
- Pre-commit hooks configuration

### Fixed
- ShellCheck warnings: properly quoted GITHUB_OUTPUT
- Actionlint configuration to only lint workflow files

## [1.0.0] - 2026-01-22

### Added
- Initial release of ZAD Actions
- **deploy** action: Deploy container images to ZAD Operations Manager
  - Support for cloning configuration from existing deployments
  - `force-clone` parameter to re-clone even if deployment exists
  - Input validation for security (alphanumeric, hyphens, underscores, dots only)
  - 60-second curl timeout to prevent hanging
- **cleanup** action: Remove ZAD deployments and GitHub resources
  - Delete ZAD deployments via Operations Manager API
  - Delete GitHub deployments (mark inactive, then delete)
  - Delete GitHub environments (requires admin token)
  - Delete container images from GHCR
  - Best-effort cleanup (continues even if individual steps fail)
- Comprehensive documentation with examples
- EUPL-1.2 license

### Security
- Input validation before logging to prevent injection attacks
- Secure handling of API keys via environment variables
- Dangerous character detection for container inputs

[2.2.0]: https://github.com/RijksICTGilde/zad-actions/releases/tag/v2.2.0
[2.1.0]: https://github.com/RijksICTGilde/zad-actions/releases/tag/v2.1.0
[2.0.1]: https://github.com/RijksICTGilde/zad-actions/releases/tag/v2.0.1
[2.0.0]: https://github.com/RijksICTGilde/zad-actions/releases/tag/v2.0.0
[1.3.0]: https://github.com/RijksICTGilde/zad-actions/releases/tag/v1.3.0
[1.2.0]: https://github.com/RijksICTGilde/zad-actions/releases/tag/v1.2.0
[1.1.0]: https://github.com/RijksICTGilde/zad-actions/releases/tag/v1.1.0
[1.0.0]: https://github.com/RijksICTGilde/zad-actions/releases/tag/v1.0.0
