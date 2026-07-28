#!/bin/bash

# Decode the event
var="eyJpZCI6IjIwODIxMDE3MTcyNzgxMDE5MTQiLCJ1c2VybmFtZSI6InN3YXJtaXN0ZXIiLCJ0ZXh0Ijoic3RhdGUgb2YgdGhpbmdzIHd0ZiBodHRwczovL3QuY28vdEx5M281bmFEMyIsImNyZWF0ZWRfYXQiOiJUdWUgSnVsIDI4IDEzOjUxOjQ3ICswMDAwIDIwMjYiLCJ1cmwiOiJodHRwczovL3guY29tL3N3YXJtaXN0ZXIvc3RhdHVzLzIwODIxMDE3MTcyNzgxMDE5MTQiLCJtZWRpYSI6WyJodHRwczovL3Bicy50d2ltZy5jb20vbWVkaWEvSE9VY2VDeldzQUFTUnd4LmpwZyIsImh0dHBzOi8vcGJzLnR3aW1nLmNvbS9tZWRpYS9IT1VjVGluWElBQUFfeTEuanBnIl19"

EVENT_JSON=$(echo "$var" | base64 -d 2>/dev/null)

if [ -z "$EVENT_JSON" ]; then
  echo "X_TRADER_NO_EVENT"
  exit 1
fi

echo "=== Event decoded ==="
echo "$EVENT_JSON" | jq .

# Extract fields
TWEET_ID=$(echo "$EVENT_JSON" | jq -r '.id // empty')
USERNAME=$(echo "$EVENT_JSON" | jq -r '.username // empty')
TEXT=$(echo "$EVENT_JSON" | jq -r '.text // empty')
URL=$(echo "$EVENT_JSON" | jq -r '.url // empty')
MEDIA=$(echo "$EVENT_JSON" | jq -r '.media[]?' 2>/dev/null)

if [ -z "$TEXT" ]; then
  echo "X_TRADER_BAD_EVENT: missing text field"
  exit 1
fi

echo ""
echo "Tweet ID: $TWEET_ID"
echo "Username: @$USERNAME"
echo "Text: $TEXT"
echo "URL: $URL"
echo "Media count: $(echo "$MEDIA" | wc -l)"
