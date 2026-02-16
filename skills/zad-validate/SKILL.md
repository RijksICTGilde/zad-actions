---
name: zad-validate
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

## Valideer een action.yml

Valideer het `deploy` of `cleanup` action.yml bestand:

1. Controleer verplichte velden: name, description, branding, input/output beschrijvingen
2. Verifieer dat `${{ inputs.* }}` referenties bestaan als gedefinieerde inputs
3. Verifieer dat output values verwijzen naar geldige step IDs
4. Controleer dat README.md overeenkomt met action.yml (inputs, outputs, voorbeelden)
5. Rapporteer problemen met regelnummers
