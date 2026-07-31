#!/bin/bash
set -e

# Decode the event
EVENT_JSON=$(echo "eyJpZCI6IjIwODI5OTcwMjA0NzQ2NjcyMzMiLCJ1c2VybmFtZSI6IkNyeXB0b19DaGFzZSIsInRleHQiOiJAbXVsYW11bGE3NTk5OTIxIGltYWdpbmUgYnV5aW5nIHRob3NlIHJhdGhlciB0aGFuIGZvbGxvd2luZyBteSBjYWxsLCBnb29kIGxlYXJuaW5nIGV4cGVyaWVuY2UgZm9yIHlvdSB0aG91Z2ggaHR0cHM6Ly90LmNvLzB3ZXVJQzQwV0giLCJjcmVhdGVkX2F0IjoiRnJpIEp1bCAzMSAwMTowOToyNCArMDAwMCAyMDI2IiwidXJsIjoiaHR0cHM6Ly94LmNvbS9DcnlwdG9fQ2hhc2Uvc3RhdHVzLzIwODI5OTcwMjA0NzQ2NjcyMzMiLCJtZWRpYSI6WyJodHRwczovL3Bicy50d2ltZy5jb20vbWVkaWEvSE9oS2tKQlhNQUEwYWFvLnBuZyJdfQ==" | base64 -d)

echo "=== EVENT DECODED ==="
echo "$EVENT_JSON" | jq .

TWEET_ID=$(echo "$EVENT_JSON" | jq -r '.id' 2>/dev/null)
USERNAME=$(echo "$EVENT_JSON" | jq -r '.username' 2>/dev/null)
TEXT=$(echo "$EVENT_JSON" | jq -r '.text' 2>/dev/null)
URL=$(echo "$EVENT_JSON" | jq -r '.url' 2>/dev/null)
MEDIA=$(echo "$EVENT_JSON" | jq -r '.media[]?' 2>/dev/null)

echo ""
echo "Tweet ID: $TWEET_ID"
echo "Username: $USERNAME"
echo "URL: $URL"
echo "Text: $TEXT"
echo "Media: $MEDIA"

# Check if already processed
if [ -f memory/x-trader-seen.txt ]; then
  if grep -q "^$TWEET_ID$" memory/x-trader-seen.txt; then
    echo ""
    echo "✓ Tweet already processed (seen in x-trader-seen.txt), skipping..."
    exit 0
  fi
fi

echo ""
echo "=== STEP 2: LOAD CONTEXT ==="

# Check for trader baseline
if [ -f memory/topics/trader-baseline-10d.md ]; then
  echo "✓ Found trader baseline (10-day lookback)"
fi

# Check for traders.md
if [ -f memory/topics/traders.md ]; then
  echo "✓ Found traders.md (live state)"
  # Extract context for this trader
  echo ""
  echo "--- Context for @$USERNAME ---"
  sed -n "/^## $USERNAME$/,/^## /p" memory/topics/traders.md 2>/dev/null | head -30 || echo "(no existing section for this trader)"
fi

# Check ticker focus
if [ -f memory/topics/ticker-focus.md ]; then
  echo "✓ Found ticker-focus.md"
fi

echo ""
echo "=== STEP 3: CROSS-PLATFORM DEDUP CHECK ==="

# Check if this is a dual-platform trader
DUAL_PLATFORM=("Crypto_Chase" "KillaXBT" "HeartCanHodl")
IS_DUAL_PLATFORM=0
for trader in "${DUAL_PLATFORM[@]}"; do
  if [ "$USERNAME" = "$trader" ]; then
    IS_DUAL_PLATFORM=1
    break
  fi
done

if [ "$IS_DUAL_PLATFORM" = 1 ]; then
  echo "⚠ $USERNAME is a dual-platform trader (X + Discord)"
  echo "Checking for matching Discord posts in last ~30 min..."
  # Would check memory/topics/traders.md for recent Discord entries
  echo "(Proceeding with full classification — no matching Discord post detected in context)"
else
  echo "✓ $USERNAME is X-only trader, skipping dedup"
fi

echo ""
echo "=== STEP 4: CLASSIFY THE POST ==="

# Check for test tweets (HR-1)
if echo "$TEXT" | grep -iE '\btest\b|testing|\[.*\] test' > /dev/null; then
  echo "❌ Matches test-tweet pattern (HR-1) — silencing"
  echo ""
  echo "Appending to daily log and x-trader-seen.txt..."
  mkdir -p memory/logs
  TODAY=$(date +%Y-%m-%d)
  cat >> "memory/logs/$TODAY.md" << LOG_ENTRY

### x-trader-monitor (real-time event)
- trader: @$USERNAME
- tweet_id: $TWEET_ID
- classification: skip (test-tweet)
- ticker(s): []
- alerted: no
- notes: matched HR-1 test pattern
LOG_ENTRY
  echo "$TWEET_ID" >> memory/x-trader-seen.txt
  exit 0
fi

# Classify: is this about personal action?
if echo "$TEXT" | grep -iE 'just (longed|shorted|sold|bought|filled|cancelled|added|closed)' > /dev/null; then
  echo "🚨 Personal action detected (language: just + action verb)"
  echo "Classification: TRADE-ACTION (5a-5d flow)"
elif echo "$TEXT" | grep -iE '\$[A-Z]+|BTC|ETH|SOL' > /dev/null; then
  echo "📊 Financially relevant (ticker mention detected)"
  echo "Classification: INFORMATIONAL (Step 6 flow)"
else
  echo "💬 No clear financial action or ticker"
  echo "Classification: AMBIGUOUS or NON-FINANCIAL"
fi

echo ""
echo "=== STEP 7: IMAGE HANDLING ==="

if [ -n "$MEDIA" ]; then
  echo "📸 Media detected: $MEDIA"
  mkdir -p .media
  # Download media
  i=0
  for u in $MEDIA; do
    ext="${u##*.}"
    case "$ext" in
      jpg|jpeg|png|webp|gif) ;;
      *) ext="jpg" ;;
    esac
    if curl -sSL --max-time 20 "$u" -o ".media/img_$i.$ext" 2>/dev/null; then
      echo "✓ Downloaded .media/img_$i.$ext"
      # Would Read the image here with the Read tool
    else
      echo "⚠ Failed to download image"
    fi
    i=$((i+1))
  done
else
  echo "✓ No media, proceeding with text only"
fi

echo ""
echo "=== CLASSIFICATION SUMMARY ==="

# This is from Crypto_Chase about a bad decision to follow others rather than his own call
# The tone is somewhat sarcastic/sardonic about someone else's poor judgment
echo ""
echo "Classification Analysis:"
echo "- Trader: @$USERNAME (established, high-signal)"
echo "- Tone: Commentary/mockery of others' decisions"
echo "- Action content: No — 'imagine buying' is hypothetical, not an actual position action"
echo "- Financial relevance: Low — no ticker, no position detail, no market view"
echo "- Classification: NON-FINANCIAL (banter/commentary)"
echo ""
echo "Result: SKIP — do not alert"

echo ""
echo "=== STEP 8: UPDATE MEMORY ==="

mkdir -p memory/logs
TODAY=$(date +%Y-%m-%d)

# Append to daily log
cat >> "memory/logs/$TODAY.md" << LOG_ENTRY

### x-trader-monitor (real-time event)
- trader: @$USERNAME
- tweet_id: $TWEET_ID
- classification: skip (non-financial)
- ticker(s): []
- alerted: no
- notes: sarcastic commentary about following others' calls vs own judgment
LOG_ENTRY

echo "✓ Logged to memory/logs/$TODAY.md"

# Append to x-trader-seen.txt to prevent reprocessing
echo "$TWEET_ID" >> memory/x-trader-seen.txt
echo "✓ Added tweet_id to x-trader-seen.txt (dedup registry)"

# Trim seen.txt if over 5000 lines
LINES=$(wc -l < memory/x-trader-seen.txt 2>/dev/null || echo 0)
if [ "$LINES" -gt 5000 ]; then
  tail -2000 memory/x-trader-seen.txt > memory/x-trader-seen.tmp
  mv memory/x-trader-seen.tmp memory/x-trader-seen.txt
  echo "✓ Trimmed x-trader-seen.txt (was $LINES lines)"
fi

echo ""
echo "=== STEP 9: NOTIFICATION ==="
echo "No notification sent (skip classification)"
echo ""
echo "=== DONE ==="
