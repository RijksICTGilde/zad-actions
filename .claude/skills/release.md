# /release <version>

1. Verify CHANGELOG.md has entry for version
2. Extract release notes from CHANGELOG.md (section for this version)
3. Create and push tags:
```bash
git tag -a v<version> -m "Release v<version>"
git push origin v<version>
git tag -fa v<major> -m "Update v<major> to v<version>"
git push origin v<major> --force
```
4. Create release with notes from changelog:
```bash
gh release create v<version> --title "v<version>" --notes "<notes from changelog>"
```
