#!/bin/bash
# Decode and process trader event

var="$1"

# Step 1: Decode
EVENT_JSON=$(echo "$var" | base64 -d 2>/dev/null)

if [ -z "$EVENT_JSON" ] || ! echo "$EVENT_JSON" | jq . &>/dev/null; then
  echo "X_TRADER_BAD_EVENT"
  exit 1
fi

# Extract fields
TWEET_ID=$(echo "$EVENT_JSON" | jq -r '.id')
USERNAME=$(echo "$EVENT_JSON" | jq -r '.username')
TEXT=$(echo "$EVENT_JSON" | jq -r '.text')
URL=$(echo "$EVENT_JSON" | jq -r '.url')
CREATED_AT=$(echo "$EVENT_JSON" | jq -r '.created_at')
MEDIA=$(echo "$EVENT_JSON" | jq -r '.media[]?' 2>/dev/null | wc -l)

echo "=== EVENT DECODED ==="
echo "ID: $TWEET_ID"
echo "User: @$USERNAME"
echo "Created: $CREATED_AT"
echo "Has media: $([ "$MEDIA" -gt 0 ] && echo "yes" || echo "no")"
echo ""
echo "TEXT:"
echo "$TEXT"
echo ""
echo "URL: $URL"
