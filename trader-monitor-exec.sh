#!/bin/bash
set -e

# Step 1: Decode the event
var="eyJpZCI6IjIwOTc1MjQyMjY5MzY5OTE5MDgiLCJ1c2VybmFtZSI6IldpbGRfUmFuZG9tbmVzcyIsInRleHQiOiJAV0JpZ2J1Y2tzIEp1c3QgY2hld2luZyB1cCBwb3NpdGlvbmluZyBhbmQgY2hvcHBpbmcgYXJvdW5kIGFzIHdlIGRpZ2VzdCB0aGUgbGF0ZXN0IG1vdmUuXG5cbjMgZGF5cyBvZiB1cCwgMyB3ZWVrcyBvZiBjaG9wLCB0aGUgQml0Y29pbiB3YXnigKZcblxuV291bGRu4oCZdCByZWFkIG11Y2ggaW50byB0aGUgUGEgdW50aWwgd2UgY2xvc2UgdGhlIGRhaWx5IGFib3ZlIDgwayBvciBiZWxvdyA3N2sgaHR0cHM6Ly90LmNvLzBxMEo0Vm1zOGgiLCJjcmVhdGVkX2F0IjoiV2VkIFNlcCAwOSAwMzoxNToyMCArMDAwMCAyMDI2IiwidXJsIjoiaHR0cHM6Ly94LmNvbS9XaWxkX1JhbmRvbW5lc3Mvc3RhdHVzLzIwOTc1MjQyMjY5MzY5OTE5MDgiLCJtZWRpYSI6WyJodHRwczovL3Bicy50d2ltZy5jb20vbWVkaWEvSFJ2bktyN2F3QUFzTnZlLmpwZyJdfQ=="

EVENT_JSON=$(echo "$var" | base64 -d 2>/dev/null)
if [ -z "$EVENT_JSON" ]; then
  echo "X_TRADER_BAD_EVENT: Failed to decode"
  exit 1
fi

echo "=== Decoded Event ==="
echo "$EVENT_JSON" | jq .

# Extract fields
TWEET_ID=$(echo "$EVENT_JSON" | jq -r '.id // empty')
USERNAME=$(echo "$EVENT_JSON" | jq -r '.username // empty')
TEXT=$(echo "$EVENT_JSON" | jq -r '.text // empty')
CREATED_AT=$(echo "$EVENT_JSON" | jq -r '.created_at // empty')
URL=$(echo "$EVENT_JSON" | jq -r '.url // empty')
MEDIA=$(echo "$EVENT_JSON" | jq -r '.media[]?' 2>/dev/null)

if [ -z "$TEXT" ]; then
  echo "X_TRADER_BAD_EVENT: No text field"
  exit 1
fi

echo ""
echo "=== Event Details ==="
echo "Tweet ID: $TWEET_ID"
echo "Username: @$USERNAME"
echo "Created: $CREATED_AT"
echo "URL: $URL"
echo "Text: $TEXT"
[ -n "$MEDIA" ] && echo "Media: $MEDIA"
