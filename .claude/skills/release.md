# /release <version>

1. Verify CHANGELOG.md has entry for version (`## [<version>]`)
2. Extract release notes from CHANGELOG for this version
3. Create and push version tag with release notes as message:
```bash
git tag -a v<version> -m "<release notes from changelog>"
git push origin v<version>
```

The release workflow handles the rest. We follow [Semantic Versioning](https://semver.org/).
