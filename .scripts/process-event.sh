#!/bin/bash
set -e

# Step 1: Decode the event
EVENT_JSON=$(echo "eyJpZCI6IjIwODIwMDU4NzE4OTUxNDY5MzQiLCJ1c2VybmFtZSI6InN3YXJtaXN0ZXIiLCJ0ZXh0IjoiQGFwZWlzc3Ryb25rIDQgaG91cnMgKEg0KSIsImNyZWF0ZWRfYXQiOiJUdWUgSnVsIDI4IDA3OjMwOjU2ICswMDAwIDIwMjYiLCJ1cmwiOiJodHRwczovL3guY29tL3N3YXJtaXN0ZXIvc3RhdHVzLzIwODIwMDU4NzE4OTUxNDY5MzQiLCJtZWRpYSI6W119" | base64 -d 2>/dev/null)

if [ -z "$EVENT_JSON" ]; then
  echo "X_TRADER_BAD_EVENT: decode failed"
  exit 1
fi

echo "=== Decoded Event ==="
echo "$EVENT_JSON" | jq .

# Extract fields
TWEET_ID=$(echo "$EVENT_JSON" | jq -r '.id' 2>/dev/null)
USERNAME=$(echo "$EVENT_JSON" | jq -r '.username' 2>/dev/null)
TEXT=$(echo "$EVENT_JSON" | jq -r '.text' 2>/dev/null)
CREATED_AT=$(echo "$EVENT_JSON" | jq -r '.created_at' 2>/dev/null)
URL=$(echo "$EVENT_JSON" | jq -r '.url' 2>/dev/null)

echo ""
echo "=== Extracted Fields ==="
echo "Tweet ID: $TWEET_ID"
echo "Username: $USERNAME"
echo "Text: $TEXT"
echo "Created: $CREATED_AT"
echo "URL: $URL"
