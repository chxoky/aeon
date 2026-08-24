#!/bin/bash
set -e

# Decode the base64 event
EVENT_JSON=$(echo "$1" | base64 -d 2>/dev/null)

# Validate JSON
if ! echo "$EVENT_JSON" | jq . >/dev/null 2>&1; then
  echo "ERROR: Invalid JSON after decoding"
  exit 1
fi

# Extract and display fields
echo "$EVENT_JSON" | jq '.'
