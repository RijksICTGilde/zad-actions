# Contributing to ZAD Actions

Thank you for your interest in contributing to ZAD Actions!

## Development Setup

### Prerequisites

- Git
- [uv](https://docs.astral.sh/uv/) (for installing pre-commit)

### Setting Up Pre-commit Hooks

```bash
# Install pre-commit as a tool
uv tool install pre-commit

# Install the git hooks
pre-commit install
```

## Development Workflow

1. **Fork the repository** and clone your fork
2. **Create a branch** for your changes: `git checkout -b feature/my-feature`
3. **Make your changes** and ensure they pass linting
4. **Test your changes** in a real workflow (see Testing below)
5. **Commit your changes** with a clear message
6. **Push and create a pull request**

## Testing

### Testing Locally

Run the pre-commit hooks to validate your changes:

```bash
pre-commit run --all-files
```

### Testing in a Workflow

To test action changes in a real workflow:

1. Push your branch to your fork
2. Reference your branch in a test workflow:
   ```yaml
   - uses: your-username/zad-actions/deploy@your-branch
   ```
3. Verify the action works as expected

## Code Style

- **Bash scripts**: Follow [Google's Shell Style Guide](https://google.github.io/styleguide/shellguide.html)
- **YAML**: Use 2-space indentation
- **Input validation**: Always validate user inputs before using them
- **Error handling**: Provide clear error messages

## Commit Messages

Use clear, descriptive commit messages:

- `feat: Add support for multiple components`
- `fix: Handle 404 response correctly`
- `docs: Update authentication documentation`
- `chore: Update CI workflow`

## Versioning

This project uses [Semantic Versioning](https://semver.org/):

- **Major** (v2.0.0): Breaking changes to action inputs/outputs
- **Minor** (v1.1.0): New features, new optional inputs
- **Patch** (v1.0.1): Bug fixes, documentation updates

## Pull Request Process

1. Update the README.md if you changed inputs/outputs
2. Update action descriptions if applicable
3. Ensure all CI checks pass
4. Request review from a maintainer

## Questions?

Open an issue with the `question` label if you have questions about contributing.
