#!/bin/bash
set -e
cd /home/runner/work/aeon/aeon

# Step 1: Decode event
EVENT_JSON=$(echo "eyJpZCI6IjIwOTA1NDQyNTI2NDAyMzU4ODIiLCJ1c2VybmFtZSI6IldpbGRfUmFuZG9tbmVzcyIsInRleHQiOiIkU1BYXG5cbipJRiogd2UgZ2V0IGEgcmVwZWF0IG9mIHRvZGF54oCZcyBhY3Rpb24gdG9tb3Jyb3csIHRoaXMgY2hhcnQgaXMgc28gY29va2VkIGJleW9uZCB3b3Jkc1xuXG5Ob2JvZHkgaXMgZ29pbmcgdG8gaGFuZCBhcm91bmQgZm9yIG11aCBBbnRocm9waWMgSVBPIGlmIHRoaXMgZGV2aWF0aW9uIGxvY2tzIGlu4oCmXG5cbihJ4oCZdmUgYWxyZWFkeSBoaWdobGlnaHRlZCB0aGF0IHRoaXMgZGV2aWF0aW9uIGlzIGxpa2VseSB0byBsb2NrIGluIG9uIGEgY3VycmVuY3ktYWRqdXN0ZWQgYmFzaXMpIGh0dHBzOi8vdC5jby9wdk95N2J6UVdGIiwiY3JlYXRlZF9hdCI6IlRodSBBdWcgMjAgMjA6NTk6MjQgKzAwMDAgMjAyNiIsInVybCI6Imh0dHBzOi8veC5jb20vV2lsZF9SYW5kb21uZXNzL3N0YXR1cy8yMDkwNTQ0MjUyNjQwMjM1ODgyIiwibWVkaWEiOlsiaHR0cHM6Ly9wYnMudHdpbWcuY29tL21lZGlhL0hRTWE2dTNiRUFBempnSy5qcGciLCJodHRwczovL3Bicy50d2ltZy5jb20vbWVkaWEvSFFNYTZ1NGFFQUFOU3QtLmpwZyIsImh0dHBzOi8vcGJzLnR3aW1nLmNvbS9tZWRpYS9IUUdTeG4zYkVBUWlZRVEuanBnIl19" | base64 -d 2>/dev/null)

if [ -z "$EVENT_JSON" ]; then
  echo "ERROR: Failed to decode event"
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
MEDIA_JSON=$(echo "$EVENT_JSON" | jq -r '.media // empty')

echo ""
echo "=== Extracted Fields ==="
echo "Tweet ID: $TWEET_ID"
echo "Username: $USERNAME"
echo "Created: $CREATED_AT"
echo "URL: $URL"
echo "Media: $MEDIA_JSON"
echo ""
echo "Text:"
echo "$TEXT"
