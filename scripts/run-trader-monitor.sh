#!/bin/bash
set -e

# Decode the event
VAR="eyJpZCI6IjIwODAyMjgwNjgwNjU1MTM3MzkiLCJ1c2VybmFtZSI6InN3YXJtaXN0ZXIiLCJ0ZXh0IjoiQGNvYmllIEp1c3QgdGhpbmsgYWJvdXQgaG93IG1hbnkgcmljaCByZXRhcmRzIHBvcnBlZCB1cCBiYWNrIHRoZW4uIFJlc3QgaW4gcGVhY2UsIGxlZ2VuZC4iLCJjcmVhdGVkX2F0IjoiVGh1IEp1bCAyMyAwOTo0NjozNCArMDAwMCAyMDI2IiwidXJsIjoiaHR0cHM6Ly94LmNvbS9zd2FybWlzdGVyL3N0YXR1cy8yMDgwMjI4MDY4MDY1NTEzNzM5IiwibWVkaWEiOltdfQ=="

EVENT_JSON=$(echo "$VAR" | base64 -d 2>/dev/null)

TWEET_ID=$(echo "$EVENT_JSON" | jq -r '.id')
USERNAME=$(echo "$EVENT_JSON" | jq -r '.username')
TEXT=$(echo "$EVENT_JSON" | jq -r '.text')
URL=$(echo "$EVENT_JSON" | jq -r '.url')
CREATED_AT=$(echo "$EVENT_JSON" | jq -r '.created_at')

echo "=== Event Decoded ==="
echo "Tweet ID: $TWEET_ID"
echo "Username: $USERNAME"
echo "Created: $CREATED_AT"
echo "Text: $TEXT"
echo "URL: $URL"

# Check if already seen
mkdir -p memory
if [ -f memory/x-trader-seen.txt ]; then
  if grep -q "^$TWEET_ID$" memory/x-trader-seen.txt; then
    echo "⚠️ Tweet already processed (duplicate)."
    exit 0
  fi
fi

# Step 2: Load context
echo ""
echo "=== Loading Context ==="
if [ -f memory/topics/traders.md ]; then
  echo "✓ traders.md exists"
  grep -A 2 "^## @$USERNAME" memory/topics/traders.md 2>/dev/null || echo "(No existing context for this trader)"
else
  echo "ℹ traders.md not yet created"
fi

# Step 4: Classification
echo ""
echo "=== Classification ==="
echo "Analyzing tweet text for financial signals..."

# Check for test tweets (HR-1)
if echo "$TEXT" | grep -iq "test"; then
  echo "🔇 Matches test-tweet pattern (HR-1) — silent skip"
  CLASSIFICATION="skip"
  ALERTED="no"
else
  # Check for personal/non-financial (Step 4A)
  # This tweet is clearly personal banter: "@cobie Just think about how many rich retards porped up back then. Rest in peace, legend."
  # No ticker, no position language, no market commentary
  echo "📌 Analysis: Personal tribute/banter, no financial signal"
  echo "   - No ticker mentioned"
  echo "   - No position language (not 'long', 'short', 'buying', 'selling', etc.)"
  echo "   - Appears to be a tribute post about a past event"
  echo "✓ Classification: Non-financial (Step 4A)"
  CLASSIFICATION="skip"
  ALERTED="no"
fi

# Step 8: Update memory (skip events don't get event lines, only daily log)
echo ""
echo "=== Memory Update ==="
mkdir -p memory/topics memory/logs

# Add to seen list
echo "$TWEET_ID" >> memory/x-trader-seen.txt
echo "✓ Added $TWEET_ID to x-trader-seen.txt"

# Trim seen list if needed
LINES=$(wc -l < memory/x-trader-seen.txt)
if [ "$LINES" -gt 5000 ]; then
  tail -2000 memory/x-trader-seen.txt > memory/x-trader-seen.tmp && mv memory/x-trader-seen.tmp memory/x-trader-seen.txt
  echo "✓ Trimmed x-trader-seen.txt from $LINES to 2000 lines"
fi

# Step 9: Log
echo ""
echo "=== Logging ==="
TODAY=$(date +%Y-%m-%d)
LOG_FILE="memory/logs/${TODAY}.md"

if [ ! -f "$LOG_FILE" ]; then
  echo "# Daily Log — $TODAY" > "$LOG_FILE"
fi

cat >> "$LOG_FILE" << EOF

### x-trader-monitor (real-time event)
- trader: @$USERNAME
- tweet_id: $TWEET_ID
- classification: $CLASSIFICATION
- ticker(s): [none]
- alerted: $ALERTED
- notes: Personal tribute/banter post — no financial signal
EOF

echo "✓ Logged to $LOG_FILE"

echo ""
echo "=== Summary ==="
echo "✓ Classification: $CLASSIFICATION (non-financial)"
echo "✓ Alert sent: $ALERTED"
echo "✓ Memory updated"
echo "✓ Task complete"
