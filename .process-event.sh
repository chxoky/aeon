#!/bin/bash
set -e

var="eyJpZCI6IjIwNzgyNjYxNTQyMzQzMTUwNjgiLCJ1c2VybmFtZSI6IldpbGRfUmFuZG9tbmVzcyIsInRleHQiOiJ3eWQgaHR0cHM6Ly90LmNvL2ZqT0pBR0tUSm0iLCJjcmVhdGVkX2F0IjoiRnJpIEp1bCAxNyAyMzo1MDozOCArMDAwMCAyMDI2IiwidXJsIjoiaHR0cHM6Ly94LmNvbS9XaWxkX1JhbmRvbW5lc3Mvc3RhdHVzLzIwNzgyNjYxNTQyMzQzMTUwNjgiLCJtZWRpYSI6W119"

# Decode the base64 JSON
EVENT_JSON=$(echo "$var" | base64 -d 2>/dev/null)

# Extract fields
TWEET_ID=$(echo "$EVENT_JSON" | jq -r '.id')
USERNAME=$(echo "$EVENT_JSON" | jq -r '.username')
TEXT=$(echo "$EVENT_JSON" | jq -r '.text')
CREATED_AT=$(echo "$EVENT_JSON" | jq -r '.created_at')
URL=$(echo "$EVENT_JSON" | jq -r '.url')
MEDIA=$(echo "$EVENT_JSON" | jq -r '.media')

echo "=== X Trader Monitor Event ==="
echo "Tweet ID: $TWEET_ID"
echo "Username: @$USERNAME"
echo "Text: $TEXT"
echo "Created: $CREATED_AT"
echo "URL: $URL"
echo "Media: $MEDIA"
echo ""
echo "Event JSON:"
echo "$EVENT_JSON" | jq .
