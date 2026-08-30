#!/bin/bash

var="eyJpZCI6IjIwOTQwOTg3ODk0ODk2MzU2MTgiLCJ1c2VybmFtZSI6IldpbGRfUmFuZG9tbmVzcyIsInRleHQiOiJGb3IgZXhhbXBsZSwgb3RoZXIgc2VudGltZW50IHN1cnZleXMgYXJlIHNob3dpbmcgdGhlIG1hcmtldCBkZWNpZGVkbHkgYmVhcmlzaFxuXG5JdOKAmXMgYSBtaXhlZCBiYWcgYXQgYmVzdCBodHRwczovL3QuY28vcktGMGlzQ3BrciIsImNyZWF0ZWRfYXQiOiJTdW4gQXVnIDMwIDE2OjIzOjUyICswMDAwIDIwMjYiLCJ1cmwiOiJodHRwczovL3guY29tL1dpbGRfUmFuZG9tbmVzcy9zdGF0dXMvMjA5NDA5ODc4OTQ4OTYzNTYxOCIsIm1lZGlhIjpbImh0dHBzOi8vcGJzLnR3aW1nLmNvbS9tZWRpYS9IUS03d0NKYXdBQUFITWwuanBnIl19"

# Step 1: Decode the event
EVENT_JSON=$(echo "${var}" | base64 -d 2>/dev/null)

if [ -z "$EVENT_JSON" ]; then
  echo "X_TRADER_BAD_EVENT: Failed to decode"
  exit 1
fi

# Extract fields
id=$(echo "$EVENT_JSON" | jq -r '.id // empty' 2>/dev/null)
username=$(echo "$EVENT_JSON" | jq -r '.username // empty' 2>/dev/null)
text=$(echo "$EVENT_JSON" | jq -r '.text // empty' 2>/dev/null)
created_at=$(echo "$EVENT_JSON" | jq -r '.created_at // empty' 2>/dev/null)
url=$(echo "$EVENT_JSON" | jq -r '.url // empty' 2>/dev/null)
media=$(echo "$EVENT_JSON" | jq -r '.media[]? // empty' 2>/dev/null)

if [ -z "$text" ]; then
  echo "X_TRADER_BAD_EVENT: No text in event"
  exit 1
fi

echo "=== DECODED EVENT ==="
echo "ID: $id"
echo "Username: $username"
echo "Created: $created_at"
echo "URL: $url"
echo "Text:"
echo "$text"
echo ""
if [ -n "$media" ]; then
  echo "Media URLs:"
  echo "$media"
  echo ""
fi

# Step 2: Check if tweet ID already seen
if [ -f "memory/x-trader-seen.txt" ]; then
  if grep -q "^${id}$" memory/x-trader-seen.txt 2>/dev/null; then
    echo "=== SKIP: Tweet already processed ==="
    exit 0
  fi
fi

# Step 3: Load context files if they exist
echo "=== CHECKING MEMORY CONTEXT ==="
if [ -f "memory/topics/traders.md" ]; then
  echo "Loaded traders.md"
else
  echo "No traders.md yet"
fi

if [ -f "memory/topics/ticker-focus.md" ]; then
  echo "Loaded ticker-focus.md"
else
  echo "No ticker-focus.md yet"
fi

# Step 4: Classify the post
echo ""
echo "=== CLASSIFICATION ==="

# Check for test tweets
if echo "$text" | grep -iq "test"; then
  echo "Classification: SKIP (test tweet)"
  echo ""
  echo "### x-trader-monitor (real-time event)"
  echo "- trader: @$username"
  echo "- tweet_id: $id"
  echo "- classification: skip"
  echo "- alerted: no"
  echo "- notes: Test tweet matched HR-1"
  exit 0
fi

# Check if this is a personal action
if echo "$text" | grep -Eiq '(just (long|short|closed|sold|bought|added)|filled|took profit|cancelled|placing|closed position|adding|cover)'; then
  echo "Classification: TRADE SIGNAL (personal action detected)"
else
  echo "Classification: INFORMATIONAL (market sentiment/commentary)"
fi

echo ""
echo "=== HANDLING IMAGES ==="
if [ -n "$media" ]; then
  echo "Image URLs found:"
  echo "$media"
  mkdir -p .media
  i=0
  for u in $media; do
    ext="${u##*.}"
    case "$ext" in
      jpg|jpeg|png|webp|gif) : ;;
      *) ext=jpg ;;
    esac
    if curl -sSL --max-time 20 "$u" -o ".media/img_$i.$ext" 2>/dev/null; then
      echo "Saved .media/img_$i.$ext"
    fi
    i=$((i+1))
  done
fi

echo ""
echo "=== RECORDING EVENT ==="
mkdir -p memory
echo "$id" >> memory/x-trader-seen.txt

# Trim x-trader-seen.txt if it gets too large
LINES=$(wc -l < memory/x-trader-seen.txt 2>/dev/null || echo 0)
if [ "$LINES" -gt 5000 ]; then
  tail -2000 memory/x-trader-seen.txt > memory/x-trader-seen.tmp && mv memory/x-trader-seen.tmp memory/x-trader-seen.txt
fi

echo "Recorded tweet ID in x-trader-seen.txt"
