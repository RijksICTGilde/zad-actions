# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **deploy** action: PR commenting feature
  - Automatically post/update a comment on PRs with the deployment URL
  - New inputs: `comment-on-pr`, `github-token`, `comment-header`
  - Upsert behavior: updates existing comment instead of creating duplicates
- **cleanup** action: PR comment update feature
  - Update the deploy PR comment to show cleanup status when PR is closed
  - New inputs: `update-pr-comment`, `comment-header`
  - New output: `pr-comment-updated`
  - Changes comment header from "🚀 Preview Deployment" to "🧹 Preview Deployment (Cleaned Up)"
- CI/CD pipeline with ShellCheck, actionlint, and yamllint
- Branch protection and governance files (CODEOWNERS, issue templates, PR template)
- CONTRIBUTING.md with development guidelines
- SECURITY.md with security policy
- Pre-commit hooks configuration

### Fixed
- ShellCheck warnings: properly quoted GITHUB_OUTPUT
- Actionlint configuration to only lint workflow files

## [1.0.0] - 2024-01-01

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

[Unreleased]: https://github.com/RijksICTGilde/zad-actions/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/RijksICTGilde/zad-actions/releases/tag/v1.0.0
