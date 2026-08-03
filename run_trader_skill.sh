#!/bin/bash
set -e

# Decode the event
var="eyJpZCI6IjIwODQyNjM2NTUxNjAzNTczMjAiLCJ1c2VybmFtZSI6IktpbGxhWEJUIiwidGV4dCI6IiRCVEMgXG5cblF1aXRlIGFuIGFnZ3Jlc3NpdmUgYW1vdW50IG9mIGxldmVyYWdlIG9wZW5pbmcgY3VycmVudGx5LlxuXG5TZWVtcyBsaWtlIGEgbG90IG9mIGxhdGUgc2hvcnRzIGFyZSBwaWxpbmcgaW4uXG5cbklmIHNwb3Qgc2VsbGluZyBzbG93cyBkb3duLCB3ZSBsaWtlbHkgc2VlIGEgc3F1ZWV6ZS9odW50LiBCdXQgaWYgc3BvdCBzZWxsaW5nIGNvbnRpbnVlcyB0byBkb21pbmF0ZSwgdGhlc2Ugc2hvcnRzIGNvdWxkIGdldCByZXdhcmRlZC4gaHR0cHM6Ly90LmNvL2VwWHJIbjR1NTIiLCJjcmVhdGVkX2F0IjoiTW9uIEF1ZyAwMyAxMzowMjozMyArMDAwMCAyMDI2IiwidXJsIjoiaHR0cHM6Ly94LmNvbS9LaWxsYVhCVC9zdGF0dXMvMjA4NDI2MzY1NTE2MDM1NzMyMCIsIm1lZGlhIjpbImh0dHBzOi8vcGJzLnR3aW1nLmNvbS9tZWRpYS9IT3pKNjhFV3dBQTlob0sucG5nIl19"

EVENT_JSON=$(echo "$var" | base64 -d 2>/dev/null) || { echo "X_TRADER_BAD_EVENT"; exit 0; }

echo "=== Decoded Event ==="
echo "$EVENT_JSON" | jq .

# Extract fields
USERNAME=$(echo "$EVENT_JSON" | jq -r '.username // empty' 2>/dev/null)
TEXT=$(echo "$EVENT_JSON" | jq -r '.text // empty' 2>/dev/null)
TWEET_ID=$(echo "$EVENT_JSON" | jq -r '.id // empty' 2>/dev/null)
URL=$(echo "$EVENT_JSON" | jq -r '.url // empty' 2>/dev/null)
MEDIA=$(echo "$EVENT_JSON" | jq -r '.media[]?' 2>/dev/null)

if [ -z "$TEXT" ] || [ -z "$USERNAME" ]; then
  echo "X_TRADER_BAD_EVENT: missing text or username"
  exit 0
fi

echo ""
echo "=== Event Fields ==="
echo "Username: $USERNAME"
echo "Tweet ID: $TWEET_ID"
echo "URL: $URL"
echo "Text: $TEXT"
echo "Media: $MEDIA"

# Check if already seen
mkdir -p memory
if grep -q "^$TWEET_ID$" memory/x-trader-seen.txt 2>/dev/null; then
  echo ""
  echo "Already processed this tweet, skipping."
  exit 0
fi

# Test tweet detection
if echo "$TEXT" | grep -iE '(^|\s)(test|testing)($|\s|\.)|(test|testing)\s+[0-9]+' > /dev/null 2>&1; then
  echo ""
  echo "HR-1 MATCH: Test tweet detected, skipping silently"
  echo "$TWEET_ID" >> memory/x-trader-seen.txt
  exit 0
fi

# Load memory if available
echo ""
echo "=== Memory Context ==="
if [ -f memory/topics/traders.md ]; then
  echo "Found traders.md"
  grep -A 20 "^## @$USERNAME" memory/topics/traders.md 2>/dev/null || echo "No existing context for @$USERNAME"
else
  echo "No traders.md yet"
fi

# Check for media
if [ -n "$MEDIA" ]; then
  echo ""
  echo "=== Fetching Media ==="
  mkdir -p .media
  i=0
  for u in $MEDIA; do
    ext="${u##*.}"
    case "$ext" in
      jpg|jpeg|png|webp|gif) : ;;
      *) ext=jpg ;;
    esac
    echo "Fetching media: $u"
    if curl -sSL --max-time 20 "$u" -o ".media/img_$i.$ext" 2>/dev/null; then
      echo "✓ Saved .media/img_$i.$ext"
    else
      echo "✗ Failed to fetch media"
    fi
    i=$((i+1))
  done
fi

# CLASSIFICATION LOGIC
echo ""
echo "=== Step 4: Classify Post ==="

# Check if this is the trader's own action (first-person action language)
if echo "$TEXT" | grep -iE '(just (longed|shorted|bought|sold)|filled my|took profit|closed|cancelled|added)' > /dev/null 2>&1; then
  echo "CLASSIFICATION: Trade action detected"

  # Determine if it's a new entry, TP, or add
  if echo "$TEXT" | grep -iE '(just (longed|shorted|bought|sold)|filled my|limit)' > /dev/null 2>&1; then
    echo "TYPE: New entry (LONG/SHORT)"
    CLASSIFICATION="trade-new-entry"
  elif echo "$TEXT" | grep -iE '(took profit|TP)' > /dev/null 2>&1; then
    echo "TYPE: Take profit / Close"
    CLASSIFICATION="mirror-full-tp"
  elif echo "$TEXT" | grep -iE 'cancelled' > /dev/null 2>&1; then
    echo "TYPE: Cancel limit"
    CLASSIFICATION="mirror-cancel"
  elif echo "$TEXT" | grep -iE 'added' > /dev/null 2>&1; then
    echo "TYPE: Conviction add"
    CLASSIFICATION="conviction-add"
  else
    CLASSIFICATION="trade-action"
  fi
else
  # Check if it's sentiment/macro/opinion (not personal action)
  if echo "$TEXT" | grep -iE '(think|believe|likely|probably|setup|level|target|watching|if .* then|opinion)' > /dev/null 2>&1; then
    echo "CLASSIFICATION: Informational (opinion/sentiment/setup)"
    CLASSIFICATION="informational"
  else
    echo "CLASSIFICATION: Unable to determine - checking for financial relevance"
    CLASSIFICATION="ambiguous"
  fi
fi

echo "Final classification: $CLASSIFICATION"

# Extract ticker if present
TICKER=$(echo "$TEXT" | grep -oE '\$[A-Z0-9]+' | head -1)
if [ -z "$TICKER" ]; then
  TICKER="(no explicit ticker)"
fi
echo "Ticker: $TICKER"

# Prepare memory update
echo ""
echo "=== Updating Memory ==="
mkdir -p memory/topics memory/logs

# Add to x-trader-seen.txt
echo "$TWEET_ID" >> memory/x-trader-seen.txt

# Update traders.md
TIMESTAMP=$(date -u +"%b %d %H:%MZ")
TRADERS_FILE="memory/topics/traders.md"

if [ ! -f "$TRADERS_FILE" ]; then
  echo "# Trader Context" > "$TRADERS_FILE"
fi

# Add trader section if not present
if ! grep -q "^## @$USERNAME" "$TRADERS_FILE"; then
  echo "" >> "$TRADERS_FILE"
  echo "## @$USERNAME" >> "$TRADERS_FILE"
  echo "" >> "$TRADERS_FILE"
  echo "**Current open positions:** TBD" >> "$TRADERS_FILE"
  echo "**Recent thesis:** TBD" >> "$TRADERS_FILE"
  echo "**Last seen:** $TIMESTAMP" >> "$TRADERS_FILE"
  echo "" >> "$TRADERS_FILE"
  echo "**Events (rolling):**" >> "$TRADERS_FILE"
fi

# Add event entry
EVENT_LINE="  - $TIMESTAMP — $CLASSIFICATION: $TICKER ${TEXT:0:50}... [$TWEET_ID]"
echo "$EVENT_LINE" >> "$TRADERS_FILE"

# Log to daily log
LOG_FILE="memory/logs/$(date +%Y-%m-%d).md"
mkdir -p memory/logs

cat >> "$LOG_FILE" << EOF

### x-trader-monitor (real-time event)
- trader: @$USERNAME
- tweet_id: $TWEET_ID
- classification: $CLASSIFICATION
- ticker(s): $TICKER
- alerted: $([ "$CLASSIFICATION" != "skip" ] && echo "yes" || echo "no")
- notes: $URL

EOF

echo "✓ Updated traders.md and daily log"

# Generate alert if classified as trade or informational
if [ "$CLASSIFICATION" != "skip" ] && [ "$CLASSIFICATION" != "informational" ]; then
  echo ""
  echo "=== ALERT ==="
  echo ""
  if [ "$CLASSIFICATION" = "trade-new-entry" ]; then
    cat << EOF
🚨 *Trade Signal — @$USERNAME*

$TICKER — LONG/SHORT
Price level: TBD

"${TEXT:0:100}..."

[$URL](URL)

Reply \`approve $TICKER\` to mirror this on Kraken, or ignore to skip.
EOF
  elif [ "$CLASSIFICATION" = "conviction-add" ]; then
    cat << EOF
➕ *Conviction Add — @$USERNAME*

@$USERNAME added to $TICKER position.

"${TEXT:0:80}..."

[$URL](URL)

Want to add to yours?
EOF
  else
    cat << EOF
🔔 *Alert — @$USERNAME*

$TICKET — $CLASSIFICATION

"${TEXT:0:100}..."

[$URL](URL)
EOF
  fi
elif [ "$CLASSIFICATION" = "informational" ]; then
  echo ""
  echo "=== INFORMATIONAL ALERT ==="
  echo ""
  cat << EOF
🐦 *[X] @$USERNAME*

${TEXT:0:200}...

[$URL](URL)
EOF
fi

echo ""
echo "=== Task Complete ==="
echo "✓ Event processed and stored"
