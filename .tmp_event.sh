#!/bin/bash
set -e

# Decode the base64 event
EVENT_B64='eyJpZCI6IjIwODEyNjUxMjA5MTE1MjQzMjAiLCJ1c2VybmFtZSI6InRyYWRpbmdfYXhlIiwidGV4dCI6IkJpdGNvaW4gdG8gYWx0Y29pbnMgZXZlcnkgdGltZSBpdCBmbGluY2hlcyBldmVuIC0xJTogaHR0cHM6Ly90LmNvL2VzVXhPbk5wWHQiLCJjcmVhdGVkX2F0IjoiU3VuIEp1bCAyNiAwNjoyNzoyNyArMDAwMCAyMDI2IiwidXJsIjoiaHR0cHM6Ly94LmNvbS90cmFkaW5nX2F4ZS9zdGF0dXMvMjA4MTI2NTEyMDkxMTUyNDMyMCIsIm1lZGlhIjpbImh0dHBzOi8vcGJzLnR3aW1nLmNvbS9hbXBsaWZ5X3ZpZGVvX3RodW1iLzIwODEyNjUwNzI5NDk1ODM4NzIvaW1nL0N6M1AyVHJjQUxhYUdFUUwuanBnIl19'

EVENT_JSON=$(echo "$EVENT_B64" | base64 -d)
echo "$EVENT_JSON" | jq .

# Extract key fields
TWEET_ID=$(echo "$EVENT_JSON" | jq -r '.id')
USERNAME=$(echo "$EVENT_JSON" | jq -r '.username')
TEXT=$(echo "$EVENT_JSON" | jq -r '.text')
URL=$(echo "$EVENT_JSON" | jq -r '.url')
MEDIA=$(echo "$EVENT_JSON" | jq -r '.media[]?' 2>/dev/null | head -1)

echo "=== EXTRACTED ==="
echo "ID: $TWEET_ID"
echo "Username: $USERNAME"
echo "Text: $TEXT"
echo "URL: $URL"
echo "Media: $MEDIA"
