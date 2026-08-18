#!/bin/bash
set -e

VAR="eyJpZCI6IjIwODk2NDA2MTUwMDkwNDY3NjQiLCJ1c2VybmFtZSI6InN3YXJtaXN0ZXIiLCJ0ZXh0IjoiQDB4YmFncyBJVFMgVFJVRSDwn5it8J+YrSIsImNyZWF0ZWRfYXQiOiJUdWUgQXVnIDE4IDA5OjA4OjQwICswMDAwIDIwMjYiLCJ1cmwiOiJodHRwczovL3guY29tL3N3YXJtaXN0ZXIvc3RhdHVzLzIwODk2NDA2MTUwMDkwNDY3NjQiLCJtZWRpYSI6W119"

EVENT_JSON=$(echo "$VAR" | base64 -d 2>/dev/null)

if [ -z "$EVENT_JSON" ]; then
  echo "X_TRADER_BAD_EVENT: $VAR"
  exit 1
fi

TEXT=$(echo "$EVENT_JSON" | jq -r '.text // ""' 2>/dev/null)
if [ -z "$TEXT" ]; then
  echo "X_TRADER_BAD_EVENT: $VAR"
  exit 1
fi

echo "$EVENT_JSON"
