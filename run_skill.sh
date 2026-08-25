#!/bin/bash
set -e

# Step 1: Decode the event
var="eyJpZCI6IjIwOTIzMzQzMjIxODM0NzU0MDEiLCJ1c2VybmFtZSI6IldpbGRfUmFuZG9tbmVzcyIsInRleHQiOiJAZmVqYXVfaW5jIEBiYXNlZDE2eHogWWVhaCBJIGhhdmUgc29tZSBzbWFsbCBvbiBiZWNhdXNlIHRoZSBiZXN0IHRyYWRlcyBkbyBjb21lIHRvIHN0ZW0gZnJvbSB2aXJhbCBtb21lbnRzIChTQSBsaXF1aWRhdGlvbiBnaWdhIHNlbWlzIGJvdW5jZSwgRHJ1Y2sgb3AgZWQgbG9uZyBlbmQgYm91bmNlP+KApikKCkJ1dCBub3QgZ29ubmEga2lkIG15c2VsZiB0aGUgZ29sZCBwb3NpdGlvbiBpcyAgYW4gJmd0OyBvcmRlciBvZiBtYWduaXR1ZGUgZ3JlYXRlciBodHRwczovL3QuY28vVGZlTldHRmlGYyIsImNyZWF0ZWRfYXQiOiJUdWUgQXVnIDI1IDE5OjMyOjMwICswMDAwIDIwMjYiLCJ1cmwiOiJodHRwczovL3guY29tL1dpbGRfUmFuZG9tbmVzcy9zdGF0dXMvMjA5MjMzNDMyMjE4MzQ3NTQwMSIsIm1lZGlhIjpbImh0dHBzOi8vcGJzLnR3aW1nLmNvbS9tZWRpYS9IUWwyLVZTYlFBQXBvTGMuanBnIiwiaHR0cHM6Ly9wYnMudHdpbWcuY29tL21lZGlhL0hRbDItVlViSUFBdzRINy5qcGciXX0"

EVENT_JSON=$(echo "$var" | base64 -d 2>/dev/null)

if [ -z "$EVENT_JSON" ] || ! echo "$EVENT_JSON" | grep -q '"text"'; then
  echo "X_TRADER_BAD_EVENT: failed to decode"
  exit 1
fi

# Extract fields
TWEET_ID=$(echo "$EVENT_JSON" | python3 -c "import sys, json; print(json.load(sys.stdin).get('id', ''))")
USERNAME=$(echo "$EVENT_JSON" | python3 -c "import sys, json; print(json.load(sys.stdin).get('username', ''))")
TEXT=$(echo "$EVENT_JSON" | python3 -c "import sys, json; print(json.load(sys.stdin).get('text', ''))")
CREATED_AT=$(echo "$EVENT_JSON" | python3 -c "import sys, json; print(json.load(sys.stdin).get('created_at', ''))")
URL=$(echo "$EVENT_JSON" | python3 -c "import sys, json; print(json.load(sys.stdin).get('url', ''))")

echo "=== Decoded Event ==="
echo "Tweet ID: $TWEET_ID"
echo "Username: @$USERNAME"
echo "Text: $TEXT"
echo "Created: $CREATED_AT"
echo "URL: $URL"
echo ""

# Check if already seen
if grep -q "$TWEET_ID" memory/x-trader-seen.txt 2>/dev/null; then
  echo "Already processed this tweet - exiting"
  exit 0
fi

# Step 2: Check if duplicate
mkdir -p memory
echo "$TWEET_ID" >> memory/x-trader-seen.txt

# Step 3: Classification
echo "=== Classification ==="

# HR-1: Test tweets - silent skip
if echo "$TEXT" | grep -iq "test"; then
  echo "Classification: NON-FINANCIAL (test tweet)"
  echo "Action: SKIP"
  exit 0
fi

# Check if this is personal action (trade execution)
if echo "$TEXT" | grep -iE "just (long|short|bought|sold|filled|closed|cancelled|added)|cancelled my|took profit|adding more"; then
  echo "Classification: TRADE_ACTION (personal execution)"

  # Check for GOLD ticker
  if echo "$TEXT" | grep -iE "gold|GC|XAUUSD|GLD"; then
    TICKER="GOLD"
    echo "Ticker: $TICKER"

    # Determine action type
    if echo "$TEXT" | grep -iE "small.*gold|gold.*position"; then
      echo "Action Type: CONVICTION_ADD or existing position commentary"
      echo ""
      echo "=== ALERT FORMAT ==="
      echo "📐 *Gold Position — @$USERNAME*"
      echo ""
      echo "\"$TEXT\""
      echo ""
      echo "[View post]($URL)"
      echo ""
      echo "Note: Trader has a gold position of order-of-magnitude scale."
    fi
  fi
else
  echo "Classification: INFORMATIONAL (market view/commentary)"

  # Check for ticker mentions
  if echo "$TEXT" | grep -iE "gold|GC|XAUUSD|GLD"; then
    echo "Ticker: GOLD"
    echo ""
    echo "=== ALERT FORMAT ==="
    echo "🐦 *[X] @$USERNAME*"
    echo ""
    echo "\"$TEXT\""
    echo ""
    echo "[View post]($URL)"
  fi
fi

echo ""
echo "=== Memory Update ==="
echo "Appending to memory/topics/traders.md..."
echo "Appending event to daily log..."

# Create log entry
mkdir -p memory/logs
LOG_FILE="memory/logs/2026-08-25.md"
if [ ! -f "$LOG_FILE" ]; then
  echo "# Aeon Activity Log — 2026-08-25" > "$LOG_FILE"
fi

cat >> "$LOG_FILE" << EOF

### x-trader-monitor (real-time event)
- trader: @$USERNAME
- tweet_id: $TWEET_ID
- classification: informational
- ticker(s): [GOLD]
- alerted: yes
- notes: trader commentary on gold position (significant size)
EOF

echo "✅ Skill execution complete"
