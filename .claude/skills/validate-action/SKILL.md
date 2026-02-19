---
name: validate-action
description: >-
  Valideer GitHub Actions action.yml bestanden voor ZAD. Gebruik bij vragen over
  'validate action', 'action.yml', 'valideer actie', 'GitHub Action controleren',
  'inputs outputs check'.
model: sonnet
allowed-tools:
  - Read(*)
  - Grep(*)
  - Glob(*)
---

# Validate GitHub Action

Deep validation of action.yml files in this repo.

## Usage

```
/validate-action <action>
```

Where `<action>` is `deploy`, `cleanup`, or `scheduled-cleanup`. If not specified, validate all.

## Validation checks

### 1. Structural validation

Read `<action>/action.yml` and verify:

- **Top-level fields exist:** `name`, `description`, `author`, `branding`, `inputs`, `outputs`, `runs`
- **Every input has:**
  - `description` (non-empty string)
  - `required` explicitly set to `true` or `false` (not omitted)
- **Every output has:**
  - `description` (non-empty string)
  - `value` referencing a valid step output

### 2. Cross-reference validation

- **Input references:** Every `${{ inputs.X }}` in `run:` blocks and `env:` mappings must correspond to a defined input `X`
- **Step output references:** Every `${{ steps.X.outputs.Y }}` must reference:
  - A step with `id: X` that exists in the action
  - An output `Y` that the step actually sets (via `>> "$GITHUB_OUTPUT"`)
- **Output values:** Every output `value: ${{ steps.X.outputs.Y }}` must reference a valid step ID and output name

### 3. Security validation

Check bash scripts in `run:` blocks for:

- **Sensitive inputs via env:** Inputs like `api-key`, tokens, and secrets must be passed via `env:` block, not interpolated directly in `run:` strings
- **curl timeouts:** Every `curl` command must have `--max-time`
- **Input validation before logging:** Inputs used in `echo` or log statements should be validated first (grep pattern check before echo)
- **Variable quoting:** All `$VARIABLE` expansions in bash should be quoted (`"$VARIABLE"`)

### 4. README sync check

Read `README.md` and compare with `<action>/action.yml`:

- **Inputs table:** Every input in action.yml should appear in README examples or documentation
- **Outputs table:** Every output in action.yml should be documented
- **Defaults:** Default values mentioned in README should match action.yml
- **Version references:** `@v1` or `@v2` references should match current major version

### 5. Report format

Report issues grouped by category with:
- File path and line number (e.g., `deploy/action.yml:42`)
- Severity: ERROR (must fix) or WARNING (should fix)
- Description of the issue
- Suggested fix

Example:
```
ERROR deploy/action.yml:83 - Input 'api-key' interpolated directly in run: block (should use env:)
WARNING README.md:45 - Input 'wait-interval' not documented in README
```
