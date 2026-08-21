#!/bin/bash
set -e

VAR='eyJpZCI6IjE1NDA0MTgwNjAzNzUyOTgwNDgiLCJjaGFubmVsX2lkIjoiMTQxMTQ5MjE4ODMxNTE5MzQxNiIsInVzZXJuYW1lIjoia2lsbGF4YnQiLCJjb250ZW50IjoiKipCVEMqKlxuXG5UaGlzIGlzIG15IGN1cnJlbnQgdGhlc2lzLiBJ4oCZbSB3YWl0aW5nIGZvciB0aGUgd2Vla2x5IGNsb3NlIGFuZCBob3Bpbmcgd2UgZ2V0IGFub3RoZXIgZW50cnkgYXJvdW5kICoqJDc5LjXigJM4MEsuKipcblxuSeKAmW0gdHJlYXRpbmcgdGhpcyBhcyBhIHNsaWdodGx5IHdpZGVyIHRyYWRlIGJlY2F1c2UgSeKAmW0gZmFpcmx5IGNvbmZpZGVudCB3ZeKAmWxsIGZvcm0gYSByYW5nZSBzb29uLiBXZSBqdXN0IGhhZCBhbiBpbnNhbmVseSBzdHJvbmcgd2Vla2x5IGFuZCBtb250aGx5IGNhbmRsZSwgYW5kIHRoZXNlIGxlZ3MgdXAgYXJlIHVzdWFsbHkgcXVpY2sgYW5kIHZpb2xlbnQgYmVmb3JlIHRoZSBtYXJrZXQgc3RhcnRzIHJhbmdpbmcuXG5cblRoZSBxdWVzdGlvbiBpcyB3aGV0aGVyIHdlIHJhbmdlIGJldHdlZW4gKiokNzDigJM4NEsgb3IgJDgw4oCTOTRLKiouIFBlcnNvbmFsbHksIEkgdGhpbmsgaXTigJlzIGEgbGl0dGxlIHRvbyBlYXJseSB0byBzdGFydCB0ZXN0aW5nIHRoZSAkOTBLcywgc28gSeKAmW0gbGVhbmluZyB0b3dhcmRzIGEgJDcw4oCTODRLIHJhbmdlLlxuXG5J4oCZZCBtdWNoIHJhdGhlciBsb29rIGZvciBjb250aW51YXRpb24gbG9uZ3MgdGhhbiBoZWRnZS4gVHJlbmQgaXMgeW91ciBmcmllbmQsIGFuZCBJIHN0aWxsIGZhdm91ciB0aGUgdXBzaWRlLiBCdXQgSSBkb27igJl0IHRoaW5rIHdlIGdvIHN0cmFpZ2h0IHVwIHdpdGhvdXQgYnVpbGRpbmcgYSByYW5nZSBmaXJzdC5cblxuVGhhdOKAmXMgdGhlIHBsYW4gSeKAmW0gcGxheWluZy4gPEAmMTQxMTUyMDY1MzAwMDk2NjI0NT4iLCJjcmVhdGVkX2F0IjoiMjAyNi0wOC0yMVQxNzo1MToyNS4xNzcwMDArMDA6MDAiLCJpc19yZXBseSI6ZmFsc2UsInJlZmVyZW5jZWRfbWVzc2FnZSI6bnVsbCwiYXR0YWNobWVudHMiOlsiaHR0cHM6Ly9jZG4uZGlzY29yZGFwcC5jb20vYXR0YWNobWVudHMvMTQxMTQ5MjE4ODMxNTE5MzQxNi8xNTQwNDE4MDU5OTY0MTIxMTIwL2ltYWdlLnBuZz9leD02YTg5ZTA5ZCZpcz02YTg4OTAxZCZobT1lYmI5Zjg5NGRiNWMyNmNmMGZkOTlkMjNkMmZmZTY0M2IxNDRhNTdiYWFlM2RjZTg2NGMyODEwYjljNjZjOGQxJiJdLCJmYXN0X3BhdGhfYWxlcnRlZCI6dHJ1ZX0='

# Step 1: Decode the event
EVENT_JSON=$(echo "$VAR" | base64 -d 2>/dev/null) || {
  echo "DISCORD_TRADER_BAD_EVENT: $VAR"
  exit 1
}

echo "=== Event decoded ==="
echo "$EVENT_JSON" | jq .

# Extract key fields
MESSAGE_ID=$(echo "$EVENT_JSON" | jq -r '.id')
CHANNEL_ID=$(echo "$EVENT_JSON" | jq -r '.channel_id')
USERNAME=$(echo "$EVENT_JSON" | jq -r '.username')
CONTENT=$(echo "$EVENT_JSON" | jq -r '.content')
CREATED_AT=$(echo "$EVENT_JSON" | jq -r '.created_at')
FAST_PATH_ALERTED=$(echo "$EVENT_JSON" | jq -r '.fast_path_alerted // false')
ATTACHMENTS=$(echo "$EVENT_JSON" | jq -r '.attachments | length')

echo ""
echo "=== Parsed fields ==="
echo "Message ID: $MESSAGE_ID"
echo "Channel ID: $CHANNEL_ID"
echo "Username: $USERNAME"
echo "Fast path alerted: $FAST_PATH_ALERTED"
echo "Content length: ${#CONTENT}"
echo "Attachments: $ATTACHMENTS"
echo ""

# Check if content is empty
if [ -z "$CONTENT" ] && [ "$ATTACHMENTS" -eq 0 ]; then
  echo "DISCORD_TRADER_BAD_EVENT: empty content and no attachments"
  exit 1
fi

# Fast-path check
if [ "$FAST_PATH_ALERTED" = "true" ]; then
  echo "✓ Fast-path already alerted - skipping Telegram, proceeding to classification & memory"
else
  echo "○ Fast-path not alerted - will process full flow including Telegram alert"
fi

echo ""
echo "=== Message content ==="
echo "$CONTENT"
