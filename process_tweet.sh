#!/bin/bash
set -e

# Decode the event
EVENT_JSON=$(echo "eyJpZCI6IjIwOTc2MjE4NTM1NjkyNzQyMTkiLCJ1c2VybmFtZSI6ImJ1bGxfZ2VuaXVzIiwidGV4dCI6IkBNaW5kQmFncyB5ZWFoIGl0IHdvdWxkIGJlIGp1c3QgYSAyMC0yNSBldGggZmxvb3IgYXQgJDQwMDAtNTAwMCBldGgiLCJjcmVhdGVkX2F0IjoiV2VkIFNlcCAwOSAwOTo0MzoxNiArMDAwMCAyMDI2IiwidXJsIjoiaHR0cHM6Ly94LmNvbS9idWxsX2dlbmlvcy9zdGF0dXMvMjA5NzYyMTg1MzU2OTI3NDIxOSIsIm1lZGlhIjpbXX0=" | base64 -d 2>/dev/null)

echo "=== Decoded Event ==="
echo "$EVENT_JSON" | jq .

# Extract fields
TWEET_ID=$(echo "$EVENT_JSON" | jq -r '.id // empty')
USERNAME=$(echo "$EVENT_JSON" | jq -r '.username // empty')
TEXT=$(echo "$EVENT_JSON" | jq -r '.text // empty')
CREATED_AT=$(echo "$EVENT_JSON" | jq -r '.created_at // empty')
URL=$(echo "$EVENT_JSON" | jq -r '.url // empty')
MEDIA_COUNT=$(echo "$EVENT_JSON" | jq '.media | length')

echo "=== Extracted Fields ==="
echo "TWEET_ID: $TWEET_ID"
echo "USERNAME: $USERNAME"
echo "TEXT: $TEXT"
echo "CREATED_AT: $CREATED_AT"
echo "URL: $URL"
echo "MEDIA_COUNT: $MEDIA_COUNT"
