# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| v4.x.x  | :white_check_mark: |
| v3.x.x  | :white_check_mark: |
| v2.x.x  | :white_check_mark: |
| v1.x.x  | :x: End of life |

## Reporting a Vulnerability

If you discover a security vulnerability in ZAD Actions, please report it responsibly:

1. **Do not** open a public GitHub issue for security vulnerabilities
2. Email the maintainers directly or use GitHub's private vulnerability reporting feature
3. Include a detailed description of the vulnerability and steps to reproduce

## Security Considerations

### API Token Handling

- Always store your ZAD API token as a GitHub secret (`ZAD_API_KEY`)
- Use a token of a service account with `Developer CI` (which reads as `Viewer`) for PR environments, not a token of a human member, which carries every role that person has
- Keep a token that may deploy to production (a service account with `Ops CI` for image redeploys, or `Ops` for everything else) in a secret of the production environment, not in a repository secret
- Every token expires, a token of a service account after 365 days at most; replace the secret before then
- Never commit tokens to your repository
- The action uses the token via environment variables and never logs it

### Input Validation

The actions validate all inputs to prevent injection attacks:
- `project-id`, `deployment-name`, and `component` are validated to contain only alphanumeric characters, hyphens, underscores, and dots
- Container-related inputs are validated to prevent command injection

### Token Permissions

Use the principle of least privilege when configuring GitHub tokens:
- `github-token`: Only needs `deployments: write` and `packages: delete` (if using container cleanup)
- `github-admin-token`: Required only for environment deletion; use a dedicated token with minimal scope

## Best Practices

1. **Pin to specific versions**: Use an exact version such as `@v4.4.0`, or a commit SHA, instead of `@v4` in production workflows for reproducibility
2. **Review actions before use**: Audit the action code before using it in your workflows
3. **Limit secret access**: Only expose secrets to jobs that need them
4. **Use environments**: Configure GitHub environments with required reviewers for production deployments
