#!/usr/bin/env bash
set -euo pipefail

BIN="${1:-applpass}"
SERVICE="example.$(date +%s).local"
ACCOUNT="bot@example.local"
PASSWORD="token-$(uuidgen | cut -d- -f1)"

echo "Adding credential for ${SERVICE}/${ACCOUNT}"
printf '%s' "$PASSWORD" | "$BIN" add --service "$SERVICE" --account "$ACCOUNT" --stdin

echo "Reading credential value"
VALUE="$($BIN get --service "$SERVICE" --account "$ACCOUNT" --value-only)"
if [[ -z "$VALUE" ]]; then
  echo "No password returned" >&2
  exit 1
fi
echo "Password retrieved (length=${#VALUE})"

echo "Listing service entries"
"$BIN" list --service "$SERVICE" --format table

echo "Cleaning up"
"$BIN" delete --service "$SERVICE" --account "$ACCOUNT" --force
