#!/bin/bash
# Decode the base64-encoded event from the Worker
# Usage: ./decode_event.sh [base64_string]

B64_INPUT="$1"

if [ -z "$B64_INPUT" ]; then
  echo "X_TRADER_NO_EVENT"
  exit 0
fi

# Decode
EVENT_JSON=$(echo "$B64_INPUT" | base64 -d 2>/dev/null)

# Check if decode succeeded and has required fields
if [ -z "$EVENT_JSON" ] || ! echo "$EVENT_JSON" | jq -e '.text' > /dev/null 2>&1; then
  echo "X_TRADER_BAD_EVENT"
  exit 1
fi

# Output decoded JSON
echo "$EVENT_JSON"
