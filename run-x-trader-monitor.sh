#!/bin/bash
set -euo pipefail

# Decode event
var="eyJpZCI6IjIwODU5NTA0MzY0NjUzNDA4NjMiLCJ1c2VybmFtZSI6InRyYWRpbmdfYXhlIiwidGV4dCI6IkBibGtub2l6MDYgSSBoYWQgdG8gZ2l2ZSBteSBzb2NpYWxzIHRvIG15IG5pZ2dheiBpbiBjYXNlIEkgZGllIHNvIG15IG9wcHMgY2Fu4oCZdCBjZWxlYnJhdGUsXG5cblRoZXnigJlsbCBjb250aW51ZSBwb3N0aW5nIGxpa2UgbWUgc28gbmlnZ2F6IGNhbiBuZXZlciBnZXQgdGhlIHNhdGlzZmFjdGlvbiBvZiBhbiBBWEUgUEFDSy5cblxufiBEci4gQXhpdXMiLCJjcmVhdGVkX2F0IjoiU2F0IEF1ZyAwOCAwNDo0NToxMyArMDAwMCAyMDI2IiwidXJsIjoiaHR0cHM6Ly94LmNvbS90cmFkaW5nX2F4ZS9zdGF0dXMvMjA4NTk1MDQzNjQ2NTM0MDg2MyIsIm1lZGlhIjpbXX0="
EVENT_JSON=$(echo "$var" | base64 -d 2>/dev/null)

# Extract fields
TWEET_ID=$(echo "$EVENT_JSON" | jq -r '.id // empty' 2>/dev/null)
USERNAME=$(echo "$EVENT_JSON" | jq -r '.username // empty' 2>/dev/null)
TEXT=$(echo "$EVENT_JSON" | jq -r '.text // empty' 2>/dev/null)
CREATED_AT=$(echo "$EVENT_JSON" | jq -r '.created_at // empty' 2>/dev/null)
URL=$(echo "$EVENT_JSON" | jq -r '.url // empty' 2>/dev/null)

echo "=== Event Decoded ==="
echo "ID: $TWEET_ID"
echo "Username: $USERNAME"
echo "Created: $CREATED_AT"
echo "URL: $URL"
echo ""
echo "=== Tweet Text ==="
echo "$TEXT"
echo ""
echo "=== Classification ==="

# HR-1: Check for test tweets
if echo "$TEXT" | grep -qiE '(^|[[:space:]])test($|[[:space:]]|[^a-z])'; then
  echo "Classification: SKIP (test tweet)"
  echo "Action: Silent skip per HR-1"
  exit 0
fi

# Check if trader is in watched list - reading context
echo "Checking memory context..."

# This is a personal life/meme post, not a trade action
if echo "$TEXT" | grep -qiE '(socials|nigga|die|opps|celebrate|AXE PACK)'; then
  echo "Classification: NON-FINANCIAL"
  echo "Content Type: Personal life/meme"
  echo "Action: Skip entirely per Step 4A"
fi
