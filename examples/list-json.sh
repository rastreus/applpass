#!/usr/bin/env bash
set -euo pipefail

BIN="${1:-applpass}"

echo "All personal passwords in JSON:"
"$BIN" list --personal-only --format json

echo "Shared passwords in table format:"
"$BIN" list --shared-only --format table
