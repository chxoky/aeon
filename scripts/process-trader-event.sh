#!/bin/bash
set -e

# Decode event from base64
EVENT_JSON=$(echo "$1" | base64 -d 2>/dev/null)

if [ -z "$EVENT_JSON" ]; then
  echo "X_TRADER_BAD_EVENT: $1"
  exit 1
fi

# Extract fields
TWEET_ID=$(echo "$EVENT_JSON" | jq -r '.id // empty')
USERNAME=$(echo "$EVENT_JSON" | jq -r '.username // empty')
TEXT=$(echo "$EVENT_JSON" | jq -r '.text // empty')
URL=$(echo "$EVENT_JSON" | jq -r '.url // empty')
MEDIA=$(echo "$EVENT_JSON" | jq -r '.media[]?' 2>/dev/null)

if [ -z "$TEXT" ]; then
  echo "X_TRADER_BAD_EVENT: no text field"
  exit 1
fi

# Output structured data
echo "TWEET_ID=$TWEET_ID"
echo "USERNAME=$USERNAME"
echo "URL=$URL"
echo "TEXT=$(echo "$TEXT" | head -c 200)"
echo "HAS_MEDIA=$([ -n "$MEDIA" ] && echo 'yes' || echo 'no')"

# Return the full JSON for further processing
echo "$EVENT_JSON"
