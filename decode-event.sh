#!/bin/bash

# Decode the base64 event data
EVENT_JSON=$(echo "eyJpZCI6IjIwODE2MDU2ODQ3ODU4MTE1MTciLCJ1c2VybmFtZSI6InN3YXJtaXN0ZXIiLCJ0ZXh0IjoiQGdhcmJ5Y2FuIDJpbjEiLCJjcmVhdGVkX2F0IjoiTW9uIEp1bCAyNyAwNTowMDo0NCArMDAwMCAyMDI2IiwidXJsIjoiaHR0cHM6Ly94LmNvbS9zd2FybWlzdGVyL3N0YXR1cy8yMDgxNjA1Njg0Nzg1ODExNTE3IiwibWVkaWEiOltdfQ==" | base64 -d 2>/dev/null)

# Extract fields
TWEET_ID=$(echo "$EVENT_JSON" | jq -r '.id')
USERNAME=$(echo "$EVENT_JSON" | jq -r '.username')
TEXT=$(echo "$EVENT_JSON" | jq -r '.text')
CREATED_AT=$(echo "$EVENT_JSON" | jq -r '.created_at')
URL=$(echo "$EVENT_JSON" | jq -r '.url')
MEDIA=$(echo "$EVENT_JSON" | jq -r '.media')

echo "=== DECODED EVENT ==="
echo "Tweet ID: $TWEET_ID"
echo "Username: $USERNAME"
echo "Text: $TEXT"
echo "Created At: $CREATED_AT"
echo "URL: $URL"
echo "Media: $MEDIA"

# Check if already seen
if [ -f memory/x-trader-seen.txt ] && grep -q "$TWEET_ID" memory/x-trader-seen.txt; then
  echo ""
  echo "⚠️  Already processed this tweet (ID: $TWEET_ID)"
  exit 0
fi

# Add to seen list
mkdir -p memory
echo "$TWEET_ID" >> memory/x-trader-seen.txt

# Trim seen list if needed
LINES=$(wc -l < memory/x-trader-seen.txt 2>/dev/null || echo 0)
if [ "$LINES" -gt 5000 ]; then
  tail -2000 memory/x-trader-seen.txt > memory/x-trader-seen.tmp && mv memory/x-trader-seen.tmp memory/x-trader-seen.txt
fi

echo ""
echo "✅ Added to seen list (total: $LINES)"
