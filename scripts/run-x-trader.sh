#!/bin/bash
set -e

# Step 1: Decode event
EVENT_JSON=$(echo "eyJpZCI6IjIwOTAwMzY1NDUwODg2MzkyMDMiLCJ1c2VybmFtZSI6InN3YXJtaXN0ZXIiLCJ0ZXh0IjoiQGljb2JlYXN0IEhleeKApiBTbW9sIGRt4oCmIEZvciBGdXR1cmUgR2VuZXJhdGlvbnMiLCJjcmVhdGVkX2F0IjoiV2VkIEF1ZyAxOSAxMToyMTo1OCArMDAwMCAyMDI2IiwidXJsIjoiaHR0cHM6Ly94LmNvbS9zd2FybWlzdGVyL3N0YXR1cy8yMDkwMDM2NTQ1MDg4NjM5MjAzIiwibWVkaWEiOltdfQ==" | base64 -d 2>/dev/null)

echo "=== Decoded Event ==="
echo "$EVENT_JSON" | jq .

TWEET_ID=$(echo "$EVENT_JSON" | jq -r '.id // empty')
USERNAME=$(echo "$EVENT_JSON" | jq -r '.username // empty')
TEXT=$(echo "$EVENT_JSON" | jq -r '.text // empty')
URL=$(echo "$EVENT_JSON" | jq -r '.url // empty')
CREATED_AT=$(echo "$EVENT_JSON" | jq -r '.created_at // empty')

echo ""
echo "=== Event Details ==="
echo "ID: $TWEET_ID"
echo "Username: $USERNAME"
echo "Text: $TEXT"
echo "URL: $URL"
echo "Created: $CREATED_AT"

# Check for duplicates
if [ -f memory/x-trader-seen.txt ]; then
  if grep -q "^$TWEET_ID$" memory/x-trader-seen.txt; then
    echo "=== DUPLICATE DETECTED ==="
    exit 0
  fi
fi

# Store this tweet ID
mkdir -p memory
echo "$TWEET_ID" >> memory/x-trader-seen.txt
LINES=$(wc -l < memory/x-trader-seen.txt 2>/dev/null || echo 0)
if [ "$LINES" -gt 5000 ]; then
  tail -2000 memory/x-trader-seen.txt > memory/x-trader-seen.tmp && mv memory/x-trader-seen.tmp memory/x-trader-seen.txt
fi

echo ""
echo "=== Classification ==="
