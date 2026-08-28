#!/bin/bash

# Decode the event
EVENT_JSON=$(echo "eyJpZCI6IjIwOTMzNzY1MjU1MjU3NTAwMjYiLCJ1c2VybmFtZSI6IldpbGRfUmFuZG9tbmVzcyIsInRleHQiOiJAX3RvbGtzIHdob29wcyBvbiAgeW91ciB3aG9vcHMgaHR0cHM6Ly90LmNvLzJQaVN1dFBiRnIiLCJjcmVhdGVkX2F0IjoiRnJpIEF1ZyAyOCAxNjozMzo1MSArMDAwMCAyMDI2IiwidXJsIjoiaHR0cHM6Ly94LmNvbS9XaWxkX1JhbmRvbW5lc3Mvc3RhdHVzLzIwOTMzNzY1MjU1MjU3NTAwMjYiLCJtZWRpYSI6WyJodHRwczovL3Bicy50d2ltZy5jb20vbWVkaWEvSFEwcTJxZ2FNQUFoWExELmpwZyJdfQ==" | base64 -d 2>/dev/null)

if [ -z "$EVENT_JSON" ]; then
  echo "X_TRADER_BAD_EVENT: failed to decode"
  exit 0
fi

echo "=== DECODED EVENT ==="
echo "$EVENT_JSON" | jq .

# Extract fields
TWEET_ID=$(echo "$EVENT_JSON" | jq -r '.id' 2>/dev/null)
USERNAME=$(echo "$EVENT_JSON" | jq -r '.username' 2>/dev/null)
TEXT=$(echo "$EVENT_JSON" | jq -r '.text' 2>/dev/null)
CREATED_AT=$(echo "$EVENT_JSON" | jq -r '.created_at' 2>/dev/null)
URL=$(echo "$EVENT_JSON" | jq -r '.url' 2>/dev/null)
MEDIA=$(echo "$EVENT_JSON" | jq -r '.media[]?' 2>/dev/null)

echo ""
echo "=== EXTRACTED FIELDS ==="
echo "ID: $TWEET_ID"
echo "Username: $USERNAME"
echo "Text: $TEXT"
echo "Created: $CREATED_AT"
echo "URL: $URL"
echo "Media: $MEDIA"
