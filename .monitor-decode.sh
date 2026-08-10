#!/bin/bash

VAR_B64="eyJpZCI6IjIwODY5NDY0NDg1NTg3MDY4MzciLCJ1c2VybmFtZSI6IldpbGRfUmFuZG9tbmVzcyIsInRleHQiOiJARXZhbl9zczYgWW91IGNhbuKAmXQgbWFrZSBpdCB1cFxuXG5PZmMgU2F5bG9yIHRyaWVzIHRvIGVxdWl2b2NhdGUgaGlzIGp1bmsgd2l0aCB0aGUgb25lIGJpZyB0ZWNoIGNvbXBhbnkgdGhhdCBoYXMgZGVjaWRlZCB0byByZWZyYWluIGZyb20gdGFraW5nIHJpc2tzIHRoaXMgZGVjYWRlIFxuXG5Kb2tlcyB3cml0ZSB0aGVtc2VsdmVzIiwiY3JlYXRlZF9hdCI6Ik1vbiBBdWcgMTAgMjI6NDM6MDEgKzAwMDAgMjAyNiIsInVybCI6Imh0dHBzOi8veC5jb20vV2lsZF9SYW5kb21uZXNzL3N0YXR1cy8yMDg2OTQ2NDQ4NTU4NzA2ODM3IiwibWVkaWEiOltdfQ=="

EVENT_JSON=$(echo "$VAR_B64" | base64 -d 2>/dev/null)

if [ -z "$EVENT_JSON" ]; then
  echo "X_TRADER_BAD_EVENT"
  exit 1
fi

echo "=== Decoded Event ==="
echo "$EVENT_JSON" | jq . 2>/dev/null || echo "$EVENT_JSON"

TWEET_ID=$(echo "$EVENT_JSON" | jq -r '.id' 2>/dev/null)
USERNAME=$(echo "$EVENT_JSON" | jq -r '.username' 2>/dev/null)
TEXT=$(echo "$EVENT_JSON" | jq -r '.text' 2>/dev/null)
TWEET_URL=$(echo "$EVENT_JSON" | jq -r '.url' 2>/dev/null)

echo ""
echo "Tweet ID: $TWEET_ID"
echo "Username: $USERNAME"
echo "URL: $TWEET_URL"
echo ""
echo "=== Tweet Text ==="
echo "$TEXT"
