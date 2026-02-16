---
name: zad-release
description: >-
  Maak een nieuwe release van ZAD Actions. Gebruik bij vragen over
  'release', 'versie', 'tag', 'version', 'publiceren', 'uitbrengen'.
model: sonnet
allowed-tools:
  - Bash(git tag *)
  - Bash(git push *)
  - Read(*)
---

## Release maken

1. Controleer dat CHANGELOG.md een entry heeft voor de versie (`## [<version>]`)
2. Extraheer de release notes uit CHANGELOG voor deze versie
3. Maak en push een versie-tag:

```bash
git tag -a v<version> -m "<release notes uit changelog>"
git push origin v<version>
```

De release workflow handelt de rest af. We volgen [Semantic Versioning](https://semver.org/).
