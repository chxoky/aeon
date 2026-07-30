#!/bin/bash
set -e

# X Trader Monitor Skill Execution
# Today: 2026-07-30

# Provided event data (base64-encoded)
VAR_INPUT='eyJpZCI6IjIwODI3MDc4NzIyMDc1NDg0MjYiLCJ1c2VybmFtZSI6InN3YXJtaXN0ZXIiLCJ0ZXh0IjoiQElmaW5kUmV0YXJkcyBJIGNhbid0IGJlbGlldmUgdGhleSBmaXJlZCBhbiBpbW1pZ3JhbnQgKEknZCBiZSByZWFsbHkgc3VycHJpc2VkIGlmIHdlcmUgYSBuYXRpdmUgcmVzaWRlbnQpIiwiY3JlYXRlZF9hdCI6IlRodSBKdWwgMzAgMDY6MDA6MjYgKzAwMDAgMjAyNiIsInVybCI6Imh0dHBzOi8veC5jb20vc3dhcm1pc3Rlci9zdGF0dXMvMjA4MjcwNzg3MjIwNzU0ODQyNiIsIm1lZGlhIjpbXX0='

# Step 1: Decode event
echo "=== STEP 1: DECODE EVENT ==="
EVENT_JSON=$(echo "${VAR_INPUT}" | base64 -d 2>/dev/null)

if [ -z "$EVENT_JSON" ]; then
  echo "ERROR: X_TRADER_BAD_EVENT - decode failed"
  exit 1
fi

# Extract fields
TWEET_ID=$(echo "$EVENT_JSON" | jq -r '.id // empty' 2>/dev/null)
USERNAME=$(echo "$EVENT_JSON" | jq -r '.username // empty' 2>/dev/null)
TEXT=$(echo "$EVENT_JSON" | jq -r '.text // empty' 2>/dev/null)
URL=$(echo "$EVENT_JSON" | jq -r '.url // empty' 2>/dev/null)
MEDIA_ARRAY=$(echo "$EVENT_JSON" | jq -r '.media | @json' 2>/dev/null)

if [ -z "$TEXT" ]; then
  echo "ERROR: X_TRADER_BAD_EVENT - empty text"
  exit 1
fi

echo "ID: $TWEET_ID"
echo "User: @$USERNAME"
echo "Text: $TEXT"
echo "URL: $URL"
echo "Media: $MEDIA_ARRAY"
echo ""

# Step 2: Check if already seen (dedup)
echo "=== STEP 2: DEDUP CHECK ==="
mkdir -p memory
if grep -q "^${TWEET_ID}$" memory/x-trader-seen.txt 2>/dev/null; then
  echo "SKIP: Already processed (ID in x-trader-seen.txt)"
  exit 0
fi

# Step 3: Load context (if files exist)
echo "=== STEP 3: LOAD CONTEXT ==="
if [ -f "memory/topics/traders.md" ]; then
  TRADER_INFO=$(grep -A 20 "## @${USERNAME}" memory/topics/traders.md 2>/dev/null || echo "(no existing context)")
  echo "Trader context available: yes"
else
  echo "Trader context: none (file doesn't exist yet)"
fi

# Step 4: Classify the post
echo "=== STEP 4: CLASSIFY POST ==="

# Check for test tweet pattern (HR-1)
if echo "$TEXT" | grep -iqE '(^|[^a-z])test([^a-z]|$)'; then
  echo "HR-1 MATCH: Test tweet - SKIP SILENTLY"
  CLASSIFICATION="skip-test"
  ALERTED="no"
else
  # Check if this looks like a financial post
  if echo "$TEXT" | grep -iqE '(\$[A-Z]{1,5}|long|short|buy|sell|position|filled|limit|market|entry|stop|profit|ticker)'; then
    echo "Pattern: Financial keywords detected"
    CLASSIFICATION="pending-review"
  else
    echo "Pattern: Non-financial content"
    # Political commentary about immigration - not financial
    CLASSIFICATION="skip-non-financial"
    ALERTED="no"
  fi
fi

if [ "$CLASSIFICATION" = "skip-test" ] || [ "$CLASSIFICATION" = "skip-non-financial" ]; then
  echo "RESULT: SKIP (non-financial)"
  ALERTED="no"
  NOTES="Non-financial content: political/social commentary"
fi

echo ""

# Step 8: Update memory (seen file and log)
echo "=== STEP 8: UPDATE MEMORY ==="
echo "$TWEET_ID" >> memory/x-trader-seen.txt

# Trim seen file if it gets too large
LINES=$(wc -l < memory/x-trader-seen.txt 2>/dev/null || echo 0)
if [ "$LINES" -gt 5000 ]; then
  echo "Trimming x-trader-seen.txt from $LINES lines"
  tail -2000 memory/x-trader-seen.txt > memory/x-trader-seen.tmp && mv memory/x-trader-seen.tmp memory/x-trader-seen.txt
fi

# Update traders.md if this warrants entry (skip entries don't get recorded)
if [ "$CLASSIFICATION" != "skip-test" ] && [ "$CLASSIFICATION" != "skip-non-financial" ]; then
  mkdir -p memory/topics

  if ! grep -q "## @${USERNAME}" memory/topics/traders.md 2>/dev/null; then
    # Create new trader section
    echo "" >> memory/topics/traders.md
    echo "## @${USERNAME}" >> memory/topics/traders.md
    echo "" >> memory/topics/traders.md
    echo "**Current open positions:** (unknown)" >> memory/topics/traders.md
    echo "**Recent thesis:** (to be updated)" >> memory/topics/traders.md
    echo "**Conviction:** Calibrating" >> memory/topics/traders.md
    echo "**Last seen:** 2026-07-30 06:00Z" >> memory/topics/traders.md
    echo "" >> memory/topics/traders.md
    echo "**Events (rolling):**" >> memory/topics/traders.md
  fi

  # Add event line (one line, ≤200 chars)
  TIMESTAMP="Jul 30 06:00Z"
  EVENT_SUMMARY=$(echo "$TEXT" | cut -c 1-50)...
  echo "  - $TIMESTAMP — $CLASSIFICATION: $EVENT_SUMMARY [$TWEET_ID]" >> memory/topics/traders.md
fi

echo "✓ Updated memory/x-trader-seen.txt"
echo ""

# Step 9: Log
echo "=== STEP 9: LOG ==="
mkdir -p memory/logs

cat >> memory/logs/2026-07-30.md << EOF

### x-trader-monitor (real-time event)
- trader: @${USERNAME}
- tweet_id: ${TWEET_ID}
- classification: ${CLASSIFICATION}
- ticker(s): [none]
- alerted: ${ALERTED}
- notes: ${NOTES:-No action required}

EOF

echo "✓ Logged to memory/logs/2026-07-30.md"
echo ""

# Final summary
echo "=== FINAL SUMMARY ==="
echo "Status: ✓ Complete"
echo "Classification: $CLASSIFICATION"
echo "Alert sent: $ALERTED"
echo "Reason: Non-financial content (political/immigration commentary)"
