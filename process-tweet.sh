#!/bin/bash

# Step 1: Decode the event
var='eyJpZCI6IjIwOTk0Nzc0MTg5Njg4MTM4MjYiLCJ1c2VybmFtZSI6ImJ1bGxfZ2VuaXVzIiwidGV4dCI6IkAxbGVtb25zb3VyIEBTYXRvc2hpU2VuZGVyIHllYWggaSBtZWFuIHNvbWV0aGluZyBlbHNlIGJ1dCB0aGFua3MgZm9yIHB1dHRpbmcgbWUgb24gbG9uZyBvbiBhcmMuIHNvIG11Y2ggZ29pbmcgb24gaSBtaXNzZWQgaXQgYmVmb3JlLiBjaGVja2luZyBpdCBvdXQgcm4iLCJjcmVhdGVkX2F0IjoiTW9uIFNlcCAxNCAxMjozNjozNyArMDAwMCAyMDI2IiwidXJsIjoiaHR0cHM6Ly94LmNvbS9idWxsX2dlbml1cy9zdGF0dXMvMjA5OTQ3NzQxODk2ODgxMzgyNiIsIm1lZGlhIjpbXX0='

EVENT_JSON=$(echo "${var}" | base64 -d 2>/dev/null)
echo "=== DECODED EVENT ==="
echo "$EVENT_JSON" | jq . 2>/dev/null || echo "$EVENT_JSON"

# Extract fields
TWEET_ID=$(echo "$EVENT_JSON" | jq -r '.id' 2>/dev/null)
USERNAME=$(echo "$EVENT_JSON" | jq -r '.username' 2>/dev/null)
TEXT=$(echo "$EVENT_JSON" | jq -r '.text' 2>/dev/null)
URL=$(echo "$EVENT_JSON" | jq -r '.url' 2>/dev/null)
MEDIA=$(echo "$EVENT_JSON" | jq -r '.media[]?' 2>/dev/null)

echo ""
echo "=== EXTRACTED FIELDS ==="
echo "Tweet ID: $TWEET_ID"
echo "Username: $USERNAME"
echo "Text: $TEXT"
echo "URL: $URL"
echo "Media: ${MEDIA:-[none]}"
