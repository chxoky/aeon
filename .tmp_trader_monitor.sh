#!/bin/bash
set -e

# Step 1: Decode the event
var='eyJpZCI6IjIxMDA0MDUzNTk3Njg2OTUyNzMiLCJ1c2VybmFtZSI6InRfaW5fY3J5cHRvIiwidGV4dCI6IkBHaWFudF9CdWxsMTIg8J+YjyIsImNyZWF0ZWRfYXQiOiJUaHUgU2VwIDE3IDAyOjAzOjU2ICswMDAwIDIwMjYiLCJ1cmwiOiJodHRwczovL3guY29tL3RfaW5fY3J5cHRvL3N0YXR1cy8yMTAwNDA1MzU5NzY4Njk1MjczIiwibWVkaWEiOltdfQ=='
EVENT_JSON=$(echo "$var" | base64 -d 2>/dev/null)

echo "=== DECODED EVENT ==="
echo "$EVENT_JSON" | jq .

# Extract fields
TWEET_ID=$(echo "$EVENT_JSON" | jq -r '.id // empty')
USERNAME=$(echo "$EVENT_JSON" | jq -r '.username // empty')
TEXT=$(echo "$EVENT_JSON" | jq -r '.text // empty')
CREATED_AT=$(echo "$EVENT_JSON" | jq -r '.created_at // empty')
URL=$(echo "$EVENT_JSON" | jq -r '.url // empty')
MEDIA=$(echo "$EVENT_JSON" | jq -r '.media // empty')

echo ""
echo "=== EXTRACTED FIELDS ==="
echo "ID: $TWEET_ID"
echo "Username: $USERNAME"
echo "Text: $TEXT"
echo "Created: $CREATED_AT"
echo "URL: $URL"
echo "Media: $MEDIA"

if [ -z "$TEXT" ]; then
  echo "X_TRADER_BAD_EVENT: empty text"
  exit 1
fi

echo ""
echo "✓ Event decoded successfully"
