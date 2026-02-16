---
name: lint
description: >-
  Run pre-commit linting voor ZAD Actions. Gebruik bij vragen over
  'lint', 'pre-commit', 'code quality', 'formatting', 'linting'.
model: sonnet
allowed-tools:
  - Bash(pre-commit *)
  - Bash(uv tool install *)
---

# Lint ZAD Actions

Run pre-commit linting with automatic fixing.

## Steps

1. **Check pre-commit is installed:**
   ```bash
   command -v pre-commit
   ```
   If not installed:
   ```bash
   uv tool install pre-commit
   pre-commit install
   ```

2. **Run pre-commit on all files:**
   ```bash
   pre-commit run --all-files
   ```

3. **If there are failures:** Read the error output carefully, then fix the issues:
   - **YAML lint errors**: Fix indentation, trailing spaces, or line length in `.yml`/`.yaml` files
   - **ShellCheck warnings**: Fix bash issues in `action.yml` `run:` blocks
   - **Trailing whitespace / end-of-file**: These are usually auto-fixed by pre-commit — just re-run
   - **actionlint errors**: Fix GitHub Actions syntax issues in `.github/workflows/` files

4. **Re-run to verify fixes:**
   ```bash
   pre-commit run --all-files
   ```

5. **Report summary:** List what was fixed and what still fails (if anything).

## Important

- Pre-commit auto-fixes some issues (trailing whitespace, end-of-file). After the first run, check if files were modified and re-run.
- Always use `uv tool install` (not `pip install`) per project conventions.
- The pre-commit config is in `.pre-commit-config.yaml` at the repo root.
