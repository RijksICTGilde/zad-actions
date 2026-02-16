---
name: release
description: >-
  Maak een nieuwe release van ZAD Actions. Gebruik bij vragen over
  'release', 'versie', 'tag', 'version', 'publiceren', 'uitbrengen'.
model: sonnet
allowed-tools:
  - Bash(git tag *)
  - Bash(git push *)
  - Bash(git fetch *)
  - Read(*)
---

# Release ZAD Actions

Create a validated release with annotated tag.

## Usage

```
/release <version>
```

Example: `/release 2.1.0`

If no version is provided, ask the user for one.

## Steps

1. **Validate semver format:**
   The version argument must match `X.Y.Z` (e.g., `2.1.0`). Reject anything else.

2. **Check for duplicate tags:**
   ```bash
   git fetch --tags
   git tag -l "v<version>"
   ```
   If the tag already exists, abort and inform the user.

3. **Validate CHANGELOG.md:**
   Read `CHANGELOG.md` and verify:
   - A `## [<version>]` section exists with content
   - The `## [Unreleased]` section is empty (all changes moved to the version section)
   - A comparison link exists at the bottom: `[<version>]: https://github.com/RijksICTGilde/zad-actions/releases/tag/v<version>`
   - The comparison links are in correct order (newest first)

   If any of these fail, fix them or tell the user what needs to change.

4. **Major version warning:**
   If the major version changes (e.g., `1.x.x` to `2.0.0`), warn the user:
   - Breaking changes require updating the `## Migration from vX` section
   - Users referencing `@v1` will NOT get this update (they need `@v2`)

5. **Extract release notes:**
   Extract the content between `## [<version>]` and the next `## [` heading from CHANGELOG.md.

6. **Create and push annotated tag:**
   ```bash
   git tag -a "v<version>" -m "<release notes>"
   git push origin "v<version>"
   ```

   The release workflow (`.github/workflows/release.yml`) handles:
   - Creating the GitHub Release
   - Updating the major version tag (e.g., `v2`)
   - Rolling back the tag on failure

## Semver rules

We follow [Semantic Versioning](https://semver.org/):
- **Major** (X.0.0): Breaking changes (removed/renamed inputs, changed behavior)
- **Minor** (x.Y.0): New features (new inputs, new actions)
- **Patch** (x.y.Z): Bug fixes, documentation changes
