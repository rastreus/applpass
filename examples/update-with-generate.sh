#!/usr/bin/env bash
set -euo pipefail

BIN="${1:-applpass}"
SERVICE="update.$(date +%s).local"
ACCOUNT="bot@example.local"

printf '%s' 'initial-secret' | "$BIN" add --service "$SERVICE" --account "$ACCOUNT" --stdin
"$BIN" update --service "$SERVICE" --account "$ACCOUNT" --generate --length 40 --force

NEW_VALUE="$($BIN get --service "$SERVICE" --account "$ACCOUNT" --value-only)"
if [[ -z "$NEW_VALUE" ]]; then
  echo "Update failed" >&2
  exit 1
fi
echo "Updated password length: ${#NEW_VALUE}"

"$BIN" delete --service "$SERVICE" --account "$ACCOUNT" --force
