#!/bin/bash

# Step 1: Decode the event
EVENT_JSON=$(echo "eyJpZCI6IjIwOTU5NTExNTkyOTkzNzUzNjciLCJ1c2VybmFtZSI6IldpbGRfUmFuZG9tbmVzcyIsInRleHQiOiJAQ3J5cHRvUGFyYWR5bWUgTXkgbWFu4oCmXG5cbllvdSBib3VnaHQgdGhvdWdoIHJpZ2h0PyBodHRwczovL3QuY28vQzJsQ3hyRUxiTiIsImNyZWF0ZWRfYXQiOiJGcmkgU2VwIDA0IDE5OjA0OjMxICswMDAwIDIwMjYiLCJ1cmwiOiJodHRwczovL3guY29tL1dpbGRfUmFuZG9tbmVzcy9zdGF0dXMvMjA5NTk1MTE1OTI5OTM3NTM2NyIsIm1lZGlhIjpbImh0dHBzOi8vcGJzLnR3aW1nLmNvbS9tZWRpYS9IUlpRZUpNYUFBQXZoMy0uanBnIl19" | base64 -d 2>/dev/null)

echo "=== DECODED EVENT ==="
echo "$EVENT_JSON" | jq . 2>/dev/null || echo "$EVENT_JSON"

# Extract key fields
TWEET_ID=$(echo "$EVENT_JSON" | jq -r '.id' 2>/dev/null)
USERNAME=$(echo "$EVENT_JSON" | jq -r '.username' 2>/dev/null)
TEXT=$(echo "$EVENT_JSON" | jq -r '.text' 2>/dev/null)
URL=$(echo "$EVENT_JSON" | jq -r '.url' 2>/dev/null)
CREATED_AT=$(echo "$EVENT_JSON" | jq -r '.created_at' 2>/dev/null)

echo ""
echo "Tweet ID: $TWEET_ID"
echo "Username: $USERNAME"
echo "Text: $TEXT"
echo "URL: $URL"
echo "Created: $CREATED_AT"

MEDIA=$(echo "$EVENT_JSON" | jq -r '.media[]?' 2>/dev/null)
if [ -n "$MEDIA" ]; then
  echo "Media URLs:"
  echo "$MEDIA"
fi
