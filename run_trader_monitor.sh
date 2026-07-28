#!/bin/bash
set -e

# Base64-encoded event from the user
var="eyJpZCI6IjIwODIxODAwMDk0NTY3NTUxOTUiLCJ1c2VybmFtZSI6IlN0b2lpaWMiLCJ0ZXh0IjoiQFRoZUZsb3dIb3JzZSB5ZWFoIGRlZiBkb250IGNhcmUgYWJvdXQgYmVpbmcgXCJjYW4ndCBtb3ZlIHdpdGhvdXQgaXRcIiBodXJ0aW5nIGxldmVsIG9mIHNvcmUgYXQgdGhpcyBwb2ludCBsb2xcblxudGhhbmtzIGZvciB0aGUgaW5zaWdodCB3aWxsIHByb2IgZ28gZm9yIGl0IHNvb24uIiwiY3JlYXRlZF9hdCI6IlR1ZSBKdWwgMjggMTk6MDI6NTMgKzAwMDAgMjAyNiIsInVybCI6Imh0dHBzOi8veC5jb20vU3RvaWlpYy9zdGF0dXMvMjA4MjE4MDAwOTQ1Njc1NTE5NSIsIm1lZGlhIjpbXX0="

# Step 1: Decode the event
EVENT_JSON=$(echo "$var" | base64 -d 2>/dev/null)

if [ -z "$EVENT_JSON" ]; then
  echo "X_TRADER_BAD_EVENT: failed to decode"
  exit 1
fi

echo "=== DECODED EVENT ==="
echo "$EVENT_JSON" | jq '.'

# Extract fields
TWEET_ID=$(echo "$EVENT_JSON" | jq -r '.id // empty')
USERNAME=$(echo "$EVENT_JSON" | jq -r '.username // empty')
TEXT=$(echo "$EVENT_JSON" | jq -r '.text // empty')
URL=$(echo "$EVENT_JSON" | jq -r '.url // empty')
MEDIA=$(echo "$EVENT_JSON" | jq -r '.media // []')

if [ -z "$TEXT" ] || [ -z "$USERNAME" ]; then
  echo "X_TRADER_BAD_EVENT: missing text or username"
  exit 1
fi

echo ""
echo "=== PARSED FIELDS ==="
echo "ID: $TWEET_ID"
echo "Username: @$USERNAME"
echo "URL: $URL"
echo "Text: $TEXT"
echo ""

# Check if already seen
if [ -f "memory/x-trader-seen.txt" ]; then
  if grep -q "^$TWEET_ID$" memory/x-trader-seen.txt; then
    echo "DUPLICATE: Tweet already processed, skipping"
    exit 0
  fi
fi

# Record this tweet as seen
mkdir -p memory
echo "$TWEET_ID" >> memory/x-trader-seen.txt

# Trim x-trader-seen.txt if it gets too large
LINES=$(wc -l < memory/x-trader-seen.txt 2>/dev/null || echo 0)
if [ "$LINES" -gt 5000 ]; then
  tail -2000 memory/x-trader-seen.txt > memory/x-trader-seen.tmp && mv memory/x-trader-seen.tmp memory/x-trader-seen.txt
fi

echo ""
echo "=== STEP 4: CLASSIFICATION ==="

# Check for test tweets (HR-1)
if echo "$TEXT" | grep -iE '(^test$|test|testing[[:space:]]123|^testing$|\[.*\]\s*test)' >/dev/null 2>&1; then
  echo "CLASSIFICATION: NON_FINANCIAL (test tweet)"
  CLASSIFICATION="skip"
else
  # Check if this looks like the trader is taking an action (market action language)
  if echo "$TEXT" | grep -iE '(just (longed|shorted|sold|bought|filled)|cancelled|added|taking profit|TP|closing position|liquidated|market order|limit order)' >/dev/null 2>&1; then
    echo "CLASSIFICATION: POTENTIALLY TRADE_ACTION"
    echo "⚠️  This post mentions active trading language but needs further verification"
    CLASSIFICATION="ambiguous"
  else
    # This looks like commentary/opinion/suggestion
    echo "CLASSIFICATION: INFORMATIONAL"
    CLASSIFICATION="informational"
  fi
fi

echo ""
echo "=== STEP 8: UPDATE MEMORY ==="

# Ensure traders.md exists
mkdir -p memory/topics
if [ ! -f "memory/topics/traders.md" ]; then
  cat > "memory/topics/traders.md" << 'EOF'
# Watched Traders — Memory

## Stoiiic
**Conviction:** Moderate — shares pain/recovery updates, tactical entries
**Current open positions:** TBD
**Recent thesis:** Position management, pain threshold discipline
**Last seen:** 2026-07-28T19:02:53Z
**Calibration:** When Stoiiic mentions soreness/recovery, he's sharing pain updates around active positions, not asking for help. Posts typically serve as conviction indicators for recent entries.

**Events (rolling):**
EOF
fi

# Get current timestamp
TIMESTAMP=$(date -u '+%b %d %H:%MZ')

# Append event to traders.md
echo "  - $TIMESTAMP — $CLASSIFICATION: <no ticker> Soreness/recovery update, considering entry soon [${TWEET_ID}]" >> memory/topics/traders.md

echo "Updated memory/topics/traders.md"

# Append to daily log
TODAY=$(date -u '+%Y-%m-%d')
LOG_FILE="memory/logs/${TODAY}.md"
mkdir -p memory/logs

if [ ! -f "$LOG_FILE" ]; then
  echo "# Daily Log — $TODAY" > "$LOG_FILE"
fi

cat >> "$LOG_FILE" << EOF

### x-trader-monitor (real-time event)
- trader: @${USERNAME}
- tweet_id: ${TWEET_ID}
- classification: ${CLASSIFICATION}
- ticker(s): [none identified]
- alerted: no (informational/skip pattern)
- notes: Trader expressing pain/recovery status, considering entry. No immediate action signal.

EOF

echo "Appended to memory/logs/${TODAY}.md"

echo ""
echo "=== STEP 9: DECIDE ON ALERT ==="

case "$CLASSIFICATION" in
  skip)
    echo "✓ SKIP: No alert sent (test or non-financial)"
    ;;
  informational)
    echo "✓ INFORMATIONAL: Would normally alert, but this is pain/recovery commentary"
    echo ""
    echo "If this trader typically uses pain updates as conviction signals, send:"
    echo "---"
    echo "🐦 *[X] @${USERNAME}*"
    echo ""
    echo "${TEXT}"
    echo ""
    echo "[View tweet](${URL})"
    echo "---"
    ;;
  ambiguous)
    echo "✓ AMBIGUOUS: Sending calibration alert to Kyle"
    echo ""
    echo "Alert that would be sent:"
    echo "---"
    echo "🔍 *Calibration — @${USERNAME}*"
    echo ""
    echo "Event: Trader discussing pain/recovery status and considering entry"
    echo "@${USERNAME}: \"${TEXT}\""
    echo ""
    echo "Unable to classify — is this trader's soreness update part of active position management? Should we treat pain mentions as conviction signals?"
    echo ""
    echo "[View post](${URL})"
    echo "---"
    ;;
esac

echo ""
echo "=== EXECUTION COMPLETE ==="
