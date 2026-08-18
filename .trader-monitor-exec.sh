#!/bin/bash
set -e

var='eyJpZCI6IjIwODk1MDM5NjAxOTMyNzQwOTUiLCJ1c2VybmFtZSI6InRyYWRpbmdfYXhlIiwidGV4dCI6IkBjcnlwdG9raWxsdWE5OSBATWlkQ3VydmVNb3J0YWwgVHJhZGluZyBwZXJwcyBvbiBtYWpvcnMvbGFyZ2UgY2FwcyBvciBoYXZpbmcgYW55IHRoZXNpcyBiZWhpbmQgYSBsZWdpdGltYXRlIGxvbmd0ZXJtIGhvbGQgW21haW5seSBjb21wYW5pZXMgdGhhdCBnZW5lcmF0ZSByZWFsIHJldmVudWUgLSB0cmFkZWZpXSBpcyBza2lsbC5cblxuQnV5aW5nIGEgc2hpdGNvaW4gbGF1bmNoZWQgb24gQlNDIHdpdGggYSB5ZWxsb3cgZGVmb3JtZWQgMTgwcCBwaXhlbCBidWxsIGFuZCBob3BpbmcgdGhhdCBDaGluZXNlIHBlb3BsZSBmaW5kIGl0IGZ1bm55IGlz4oCmIGdhbWJsaW5nLlxuXG5PciBidXlpbmcgc29tZXRoaW5nIGhvcGluZyB0aGF0IHNvbWVvbmUgb24gQ1QgY2FuIGJhaXQgQ1ogaW50byDigJxpbnRlcmFjdGluZ+KAnSBpcyBhZ2Fpbuig4oCmIGdhbWJsaW5nLlxuXG5BdCBiZXN0LCBjb21wYXJhYmxlIHRvIHBva2VyLlxuXG5BdCB3b3JzdCwgc3Bpbm5pbmcgc2xvdHMuXG5cbn4gRHIuIEF4aXVzLiIsImNyZWF0ZWRfYXQiOiJUdWUgQXVnIDE4IDAwOjA1OjM5ICswMDAwIDIwMjYiLCJ1cmwiOiJodHRwczovL3guY29tL3RyYWRpbmdfYXhlL3N0YXR1cy8yMDg5NTAzOTYwMTkzMjc0MDk1IiwibWVkaWEiOltdfQ=='

# Decode event
EVENT_JSON=$(echo "$var" | base64 -d 2>/dev/null)

if [ -z "$EVENT_JSON" ]; then
  echo "ERROR: Failed to decode event"
  exit 1
fi

echo "=== Decoded Event ==="
echo "$EVENT_JSON" | jq .

# Extract key fields
TWEET_ID=$(echo "$EVENT_JSON" | jq -r '.id')
USERNAME=$(echo "$EVENT_JSON" | jq -r '.username')
TEXT=$(echo "$EVENT_JSON" | jq -r '.text')
CREATED_AT=$(echo "$EVENT_JSON" | jq -r '.created_at')
URL=$(echo "$EVENT_JSON" | jq -r '.url')
MEDIA=$(echo "$EVENT_JSON" | jq -r '.media | length')

echo ""
echo "=== Event Details ==="
echo "Tweet ID: $TWEET_ID"
echo "Username: $USERNAME"
echo "Created: $CREATED_AT"
echo "URL: $URL"
echo "Media count: $MEDIA"
echo ""
echo "Text:"
echo "$TEXT"
