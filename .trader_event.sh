#!/bin/bash

var="eyJpZCI6IjIwODc2OTMyNTUxNjkxNzk5NTIiLCJ1c2VybmFtZSI6IlN0b2lpaWMiLCJ0ZXh0IjoiZXZlcnkgb2JzdGFjbGUgeW91IG92ZXJjb21lIHRvZGF5IGlzIGEgZ2lmdCB0byB0aGUgcGVyc29uIHlvdSdsbCBiZSB0b21vcnJvdy4iLCJjcmVhdGVkX2F0IjoiVGh1IEF1ZyAxMyAwMDoxMDozNCArMDAwMCAyMDI2IiwidXJsIjoiaHR0cHM6Ly94LmNvbS9TdG9paWljL3N0YXR1cy8yMDg3NjkzMjU1MTY5MTc5OTUyIiwibWVkaWEiOltdfQ=="

# Step 1: Decode the base64 event
EVENT_JSON=$(echo "$var" | base64 -d 2>/dev/null)

# Validate JSON
if ! echo "$EVENT_JSON" | jq . > /dev/null 2>&1; then
  echo "X_TRADER_BAD_EVENT: failed to decode"
  exit 1
fi

echo "=== Decoded Event ==="
echo "$EVENT_JSON" | jq .

# Extract fields
TWEET_ID=$(echo "$EVENT_JSON" | jq -r '.id')
USERNAME=$(echo "$EVENT_JSON" | jq -r '.username')
TWEET_TEXT=$(echo "$EVENT_JSON" | jq -r '.text')
CREATED_AT=$(echo "$EVENT_JSON" | jq -r '.created_at')
URL=$(echo "$EVENT_JSON" | jq -r '.url')
MEDIA=$(echo "$EVENT_JSON" | jq -r '.media[]?' 2>/dev/null)

echo ""
echo "=== Extracted Fields ==="
echo "ID: $TWEET_ID"
echo "Username: $USERNAME"
echo "Text: $TWEET_TEXT"
echo "Created: $CREATED_AT"
echo "URL: $URL"
echo "Media URLs: $(echo "$MEDIA" | wc -l) items"

# Store for later use
export TWEET_ID USERNAME TWEET_TEXT CREATED_AT URL EVENT_JSON
