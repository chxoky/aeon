#!/bin/bash
set -e

# Step 1: Decode the event
VAR_ENCODED='eyJpZCI6IjIwODU2OTAzMDU5NTM4OTg4MzgiLCJ1c2VybmFtZSI6IkhlYXJ0Q2FuSG9kbCIsInRleHQiOiJBbm90aGVyIHBsYW5lIGhpdHRpbmcgdGhlIGJ0YyB0b3dlciIsImNyZWF0ZWRfYXQiOiJGcmkgQXVnIDA3IDExOjMxOjMzICswMDAwIDIwMjYiLCJ1cmwiOiJodHRwczovL3guY29tL0hlYXJ0Q2FuSG9kbC9zdGF0dXMvMjA4NTY5MDMwNTk1Mzg5ODgzOCIsIm1lZGlhIjpbXX0='
EVENT_JSON=$(echo "$VAR_ENCODED" | base64 -d 2>/dev/null)

if [ -z "$EVENT_JSON" ]; then
  echo "X_TRADER_BAD_EVENT"
  exit 1
fi

echo "=== DECODED EVENT ==="
echo "$EVENT_JSON" | jq .
echo ""

# Extract fields
TWEET_ID=$(echo "$EVENT_JSON" | jq -r '.id')
USERNAME=$(echo "$EVENT_JSON" | jq -r '.username')
TEXT=$(echo "$EVENT_JSON" | jq -r '.text')
CREATED_AT=$(echo "$EVENT_JSON" | jq -r '.created_at')
URL=$(echo "$EVENT_JSON" | jq -r '.url')
MEDIA=$(echo "$EVENT_JSON" | jq -r '.media | length')

echo "Tweet ID: $TWEET_ID"
echo "Username: $USERNAME"
echo "Text: $TEXT"
echo "URL: $URL"
echo "Media count: $MEDIA"
echo ""

# Check for duplicate in seen tweets
if [ -f memory/x-trader-seen.txt ] && grep -q "^$TWEET_ID" memory/x-trader-seen.txt; then
  echo "DUPLICATE: Tweet already processed"
  exit 0
fi

# Export for later use
echo "TWEET_ID=$TWEET_ID" > /tmp/trader-event.env
echo "USERNAME=$USERNAME" >> /tmp/trader-event.env
echo "TEXT=$TEXT" >> /tmp/trader-event.env
echo "URL=$URL" >> /tmp/trader-event.env
echo "MEDIA_COUNT=$MEDIA" >> /tmp/trader-event.env
echo "EVENT_JSON=$EVENT_JSON" >> /tmp/trader-event.env

echo "✓ Event decoded and extracted"
