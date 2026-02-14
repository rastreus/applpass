---
name: applpass-commands
description: Example skill with common applpass command patterns for automation agents.
allowed-tools: Bash(applpass *)
---

# applpass Command Patterns (Example)

Use these patterns when you need reliable command-line keychain operations.

## Principles

- Prefer `--stdin` for secret input to avoid shell history leakage.
- Use `--value-only` for machine parsing.
- Use `--force` in non-interactive automation where prompts are not possible.
- Never print password values in logs unless explicitly required.

## Add or Update Secret

```bash
# Add from stdin
printf '%s' "$SECRET" | applpass add --service "$SERVICE" --account "$ACCOUNT" --stdin

# Update from stdin (non-interactive)
printf '%s' "$SECRET" | applpass update --service "$SERVICE" --account "$ACCOUNT" --stdin --force
```

## Read Secret for a Command

```bash
TOKEN="$(applpass get --service "$SERVICE" --account "$ACCOUNT" --value-only)"
if [[ -z "$TOKEN" ]]; then
  echo "Secret not available" >&2
  exit 1
fi
```

## List Items for Auditing

```bash
applpass list --service "$SERVICE" --format table
applpass list --shared-only --format json
```

## Cleanup Pattern

```bash
# Single account
applpass delete --service "$SERVICE" --account "$ACCOUNT" --force

# Entire service namespace
applpass delete --service "$SERVICE" --all-accounts --force
```

## Generate Standalone Passwords

```bash
applpass generate --length 40
applpass generate --count 5 --no-symbols
```
