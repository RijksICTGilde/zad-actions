# Coding Rules

## YAML (action.yml)

- 2-space indentation
- Quote strings in `with:` blocks
- Use `|` for multi-line bash
- Always set `required: true/false` and `description` for inputs/outputs

## Bash

Validate inputs BEFORE logging (prevents injection):
```bash
if ! echo "$INPUT" | grep -qE '^[a-zA-Z0-9._-]+$'; then
  echo "Error: invalid characters"; exit 1
fi
echo "Processing: $INPUT"
```

Best-effort pattern (don't fail entire action on one step):
```bash
if some_command; then
  echo "deleted=true" >> "$GITHUB_OUTPUT"
else
  echo "::warning::Step failed but continuing"
  echo "deleted=false" >> "$GITHUB_OUTPUT"
fi
```

HTTP response handling:
```bash
RESPONSE=$(curl -s -w "\n%{http_code}" --max-time 60 "$URL")
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')
```

## Security

- Never log secrets
- Use env vars for sensitive data, not args
- Always `--max-time` on curl
- Quote all `"$VAR"` expansions

## Commits

- Before committing, always update CHANGELOG.md under [Unreleased]
- Do NOT add "Co-Authored-By: Claude" to commit messages

## Documentation

When changing action.yml inputs/outputs, update the README.md tables:
- Inputs: Name | Required | Default | Description
- Outputs: Name | Description
