#!/bin/bash
set -e

# Passed via environment
var="eyJpZCI6IjIwOTk1MTYwNjIwOTg0MzI0MDYiLCJ1c2VybmFtZSI6IldpbGRfUmFuZG9tbmVzcyIsInRleHQiOiJBbm90aGVyIGRheSB3aGVyZSBlbmVyZ3kgc3RvY2tzIGFyZSBzb2xkIGRlc3BpdGUgb2lsIHN0YXlpbmcgYmlkIGh0dHBzOi8vdC5jby9WNGVCWTdUa1FyIiwiY3JlYXRlZF9hdCI6Ik1vbiBTZXAgMTQgMTU6MTA6MTAgKzAwMDAgMjAyNiIsInVybCI6Imh0dHBzOi8veC5jb20vV2lsZF9SYW5kb21uZXNzL3N0YXR1cy8yMDk5NTE2MDYyMDk4NDMyNDA2IiwibWVkaWEiOlsiaHR0cHM6Ly9wYnMudHdpbWcuY29tL21lZGlhL0hTTDZ1eGNiZ0FBRlVoRy5qcGciLCJodHRwczovL3Bicy50d2ltZy5jb20vbWVkaWEvSFNMNnV4T2FrQUFCckppLmpwZyJdfQ=="

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
