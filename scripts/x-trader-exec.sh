#!/bin/bash
set -e

# Use provided var or fall back to environment variable
VAR="${1:-${var}}"

# Step 1: Decode event
EVENT_JSON=$(echo "$VAR" | base64 -d 2>/dev/null)

if [ -z "$EVENT_JSON" ]; then
  echo "X_TRADER_BAD_EVENT"
  exit 1
fi

echo "=== Event Decoded ==="
echo "$EVENT_JSON" | jq '.'

# Extract fields
TWEET_ID=$(echo "$EVENT_JSON" | jq -r '.id // empty' 2>/dev/null)
USERNAME=$(echo "$EVENT_JSON" | jq -r '.username // empty' 2>/dev/null)
TEXT=$(echo "$EVENT_JSON" | jq -r '.text // empty' 2>/dev/null)
URL=$(echo "$EVENT_JSON" | jq -r '.url // empty' 2>/dev/null)
CREATED_AT=$(echo "$EVENT_JSON" | jq -r '.created_at // empty' 2>/dev/null)

if [ -z "$TEXT" ] || [ -z "$USERNAME" ]; then
  echo "X_TRADER_BAD_EVENT: Missing text or username"
  exit 1
fi

echo ""
echo "=== Event Fields ==="
echo "Tweet ID: $TWEET_ID"
echo "Username: @$USERNAME"
echo "URL: $URL"
echo "Created: $CREATED_AT"
echo "Text: $TEXT"
