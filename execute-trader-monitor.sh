#!/bin/bash
set -e

# Passed via environment
var="eyJpZCI6IjIwODI0OTEwOTY5NTM3Mzc2OTEiLCJ1c2VybmFtZSI6InRyYWRpbmdfYXhlIiwidGV4dCI6IkBwdW1wc2Nob2xhciBI4oCZdmUgYmVlbiBhcm91bmQgdGhlIGJsb2NrLlxuXG5+IERyLiBBeGl1cy4iLCJjcmVhdGVkX2F0IjoiV2VkIEp1bCAyOSAxNTozOTowMiArMDAwMCAyMDI2IiwidXJsIjoiaHR0cHM6Ly94LmNvbS90cmFkaW5nX2F4ZS9zdGF0dXMvMjA4MjQ5MTA5Njk1MzczNzY5MSIsIm1lZGlhIjpbXX0="

# Step 1: Decode event
EVENT_JSON=$(echo "$var" | base64 -d 2>/dev/null)
if [ -z "$EVENT_JSON" ]; then
  echo "X_TRADER_BAD_EVENT: Failed to decode base64"
  exit 1
fi

# Extract fields
TWEET_ID=$(echo "$EVENT_JSON" | jq -r '.id // empty' 2>/dev/null)
USERNAME=$(echo "$EVENT_JSON" | jq -r '.username // empty' 2>/dev/null)
TEXT=$(echo "$EVENT_JSON" | jq -r '.text // empty' 2>/dev/null)
URL=$(echo "$EVENT_JSON" | jq -r '.url // empty' 2>/dev/null)
CREATED_AT=$(echo "$EVENT_JSON" | jq -r '.created_at // empty' 2>/dev/null)

if [ -z "$TEXT" ] || [ -z "$TWEET_ID" ]; then
  echo "X_TRADER_BAD_EVENT: Missing text or id in event"
  exit 1
fi

echo "✓ Decoded event:"
echo "  Tweet ID: $TWEET_ID"
echo "  Username: @$USERNAME"
echo "  Created: $CREATED_AT"
echo "  Text length: ${#TEXT} chars"
echo ""
