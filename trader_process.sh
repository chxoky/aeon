#!/bin/bash
set -e

# Decode base64 event
B64_DATA="eyJpZCI6IjIwOTA1MDIzMDUzNjc4NjM1NjYiLCJ1c2VybmFtZSI6IktpbGxhWEJUIiwidGV4dCI6IkkgYmVsaWV2ZSB0aGUgJEJUQyBib3R0b20gaXMgaW4uIFxuXG5BZnRlciB0aGlzIGxlZyB1cHdhcmRzLCB3ZSBjYW4gZXhwZWN0IGEgcmFuZ2UgdG8gZGV2ZWxvcC4gVGhpcyByYW5nZSB3b3VsZCBsaWtlbHkgcmVwcmVzZW50IGFjY3VtdWxhdGlvbiBiZWZvcmUgZXhwYW5zaW9uLiBcblxuSSBkaWQgd2FybiB5b3UgdGhhdCB3ZSB3ZXJlIGluIHRoZSBtYW5pcHVsYXRpb24gcGhhc2UuIFxuXG5JIGd1ZXNzIHBlb3BsZSBqdXN0IGNob3NlIG5vdCB0byBiZWxpZXZlIGl0LiBUeXBpY2FsLiBodHRwczovL3QuY28vdFRhT3RSU3lzUyIsImNyZWF0ZWRfYXQiOiJUaHUgQXVnIDIwIDE4OjEyOjQzICswMDAwIDIwMjYiLCJ1cmwiOiJodHRwczovL3guY29tL0tpbGxhWEJUL3N0YXR1cy8yMDkwNTAyMzA1MzY3ODYzNTY2IiwibWVkaWEiOlsiaHR0cHM6Ly9wYnMudHdpbWcuY29tL21lZGlhL0hRTHptczNYY0FFN292bS5qcGciLCJodHRwczovL3Bicy50d2ltZy5jb20vbWVkaWEvSEtFZ3dsUFhBQUFkVW5NLmpwZyJdfQ=="

EVENT_JSON=$(echo "$B64_DATA" | base64 -d)

if [ -z "$EVENT_JSON" ]; then
  echo "X_TRADER_BAD_EVENT"
  exit 1
fi

# Extract fields
TWEET_ID=$(echo "$EVENT_JSON" | jq -r '.id')
USERNAME=$(echo "$EVENT_JSON" | jq -r '.username')
TEXT=$(echo "$EVENT_JSON" | jq -r '.text')
URL=$(echo "$EVENT_JSON" | jq -r '.url')
MEDIA=$(echo "$EVENT_JSON" | jq -c '.media')

echo "=== EVENT DECODED ==="
echo "ID: $TWEET_ID"
echo "Username: $USERNAME"
echo "Text:"
echo "$TEXT"
echo ""
echo "URL: $URL"
echo "Media: $MEDIA"
echo ""

# Step 8a: Check if already seen
mkdir -p memory
if [ -f memory/x-trader-seen.txt ]; then
  if grep -q "^$TWEET_ID$" memory/x-trader-seen.txt; then
    echo "Already processed this tweet, stopping."
    exit 0
  fi
fi

echo "TWEET_ID=$TWEET_ID" >> /tmp/trader_vars.sh
echo "USERNAME=$USERNAME" >> /tmp/trader_vars.sh
echo "TEXT=$TEXT" >> /tmp/trader_vars.sh
echo "URL=$URL" >> /tmp/trader_vars.sh
echo "MEDIA=$MEDIA" >> /tmp/trader_vars.sh
