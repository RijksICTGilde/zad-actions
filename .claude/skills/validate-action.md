# /validate-action <action>

Validate `deploy` or `cleanup` action.yml:

1. Check required fields: name, description, branding, input/output descriptions
2. Verify `${{ inputs.* }}` references exist
3. Verify output values reference valid step IDs
4. Check README.md matches action.yml
5. Report issues with line numbers
