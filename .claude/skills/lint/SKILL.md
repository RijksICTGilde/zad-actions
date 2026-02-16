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

Run `pre-commit run --all-files` om alle linting checks uit te voeren.

Als pre-commit niet geinstalleerd is:

```bash
uv tool install pre-commit
pre-commit install
```
