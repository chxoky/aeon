#!/bin/bash
set -e

VAR="eyJpZCI6IjIwOTA4MDUzMTA4ODU2ODM1NTkiLCJ1c2VybmFtZSI6InN3YXJtaXN0ZXIiLCJ0ZXh0IjoiQEFsdWNhcmRUcmFkZXMgT2gsIEkgZGlkbid0IHNlZSB5b3VyIHJlcGx5LiBZZWFoLCBJIGFncmVlIHdpdGggeW91ICsgdHkgZm9yIGRpcyB3b3Jkcy4gYW5kIGdlbmVyYWxseSBzcGVha2luZywgdGhlIGZvbGtzIGluIHRoZSBncm91cCBjaGF0cyBrbm93IHZlcnkgd2VsbCB0aGF0IEknbSBnb29kIGF0IGRvaW5nIG15IGpvYi4gU28sIGlmIHlvdSB0YWtlIGEgbG9vaywgeW91J2xsIHNlZSB0aGF0IHdlIGhhdmUgYSBsb3Qgb2YgbXV0dWFscy4gQXMgZmFyIGFzIEknbSBjb25jZXJuZWQsIHRoYXQncyB0aGUgbWFpbiBtZWFzdXJlIG9mIHN1Y2Nlc3MuIiwiY3JlYXRlZF9hdCI6IkZyaSBBdWcgMjEgMTQ6MTY6NDYgKzAwMDAgMjAyNiIsInVybCI6Imh0dHBzOi8veC5jb20vc3dhcm1pc3Rlci9zdGF0dXMvMjA5MDgwNTMxMDg4NTY4MzU1OSIsIm1lZGlhIjpbXX0="

# Step 1: Decode event
EVENT_JSON=$(echo "$VAR" | base64 -d 2>/dev/null)

if [ -z "$EVENT_JSON" ]; then
  echo "X_TRADER_BAD_EVENT"
  exit 1
fi

echo "=== Event Decoded ==="
echo "$EVENT_JSON" | jq '.'

# Extract fields
TWEET_ID=$(echo "$EVENT_JSON" | jq -r '.id // empty' 2>/dev/null)
USERNAME=$(echo "$EVENT_JSON" | jq -r '.username // empty' 2>/dev/null)
TEXT=$(echo "$EVENT_JSON" | jq -r '.text // empty' 2>/dev/null)
URL=$(echo "$EVENT_JSON" | jq -r '.url // empty' 2>/dev/null)
CREATED_AT=$(echo "$EVENT_JSON" | jq -r '.created_at // empty' 2>/dev/null)

if [ -z "$TEXT" ] || [ -z "$USERNAME" ]; then
  echo "X_TRADER_BAD_EVENT: Missing text or username"
  exit 1
fi

echo ""
echo "=== Event Fields ==="
echo "Tweet ID: $TWEET_ID"
echo "Username: @$USERNAME"
echo "URL: $URL"
echo "Created: $CREATED_AT"
echo "Text: $TEXT"
