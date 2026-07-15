#!/bin/bash
set -e

VAR="eyJpZCI6IjIwNzc0MjgyMDI4NjQwMDE0NDkiLCJ1c2VybmFtZSI6IkNyeXB0b19DaGFzZSIsInRleHQiOiJNZXNzaSBpcyB0aGUgZ29hdCwgYnV0IEkgdGhpbmsgS2FuZSBhbmQgQmVsbGluZ2hhbSBhcmUgc2ltcGx5IHBlYWtpbmcgYXRtLCBleHBlcmllbmNlICsgeW91dGguIEVuZ2xhbmQgdGFrZXMgaXQuIGh0dHBzOi8vdC5jby9DYlh5RlFNbURnIiwiY3JlYXRlZF9hdCI6IldlZCBKdWwgMTUgMTY6MjA6NTQgKzAwMDAgMjAyNiIsInVybCI6Imh0dHBzOi8veC5jb20vQ3J5cHRvX0NoYXNlL3N0YXR1cy8yMDc3NDI4MjAyODY0MDAxNDQ5IiwibWVkaWEiOltdfQ=="

# Step 1: Decode the event
EVENT_JSON=$(echo "$VAR" | base64 -d 2>/dev/null)

if [ -z "$EVENT_JSON" ]; then
  echo "X_TRADER_BAD_EVENT: Failed to decode"
  exit 1
fi

# Pretty-print for verification
echo "=== DECODED EVENT ==="
echo "$EVENT_JSON" | jq .

# Extract fields
ID=$(echo "$EVENT_JSON" | jq -r '.id // empty')
USERNAME=$(echo "$EVENT_JSON" | jq -r '.username // empty')
TEXT=$(echo "$EVENT_JSON" | jq -r '.text // empty')
CREATED_AT=$(echo "$EVENT_JSON" | jq -r '.created_at // empty')
URL=$(echo "$EVENT_JSON" | jq -r '.url // empty')

if [ -z "$TEXT" ]; then
  echo "X_TRADER_BAD_EVENT: Missing text field"
  exit 1
fi

echo ""
echo "=== EXTRACTED FIELDS ==="
echo "ID: $ID"
echo "USERNAME: $USERNAME"
echo "TEXT: $TEXT"
echo "CREATED_AT: $CREATED_AT"
echo "URL: $URL"
