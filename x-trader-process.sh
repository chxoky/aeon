#!/bin/bash
set -e

var="eyJpZCI6IjIwODA3MjUyNDk1NTgyOTg4MDUiLCJ1c2VybmFtZSI6IldpbGRfUmFuZG9tbmVzcyIsInRleHQiOiJGYWRlZD8gQEV2YW5fc3M2IiwiY3JlYXRlZF9hdCI6IkZyaSBKdWwgMjQgMTg6NDI6MTIgKzAwMDAgMjAyNiIsInVybCI6Imh0dHBzOi8veC5jb20vV2lsZF9SYW5kb21uZXNzL3N0YXR1cy8yMDgwNzI1MjQ5NTU4Mjk4ODA1IiwibWVkaWEiOltdfQ=="

# Step 1: Decode event
echo "=== Step 1: Decode event ==="
EVENT_JSON=$(echo "$var" | base64 -d 2>/dev/null)
echo "$EVENT_JSON" | jq .

# Extract fields
TWEET_ID=$(echo "$EVENT_JSON" | jq -r '.id')
USERNAME=$(echo "$EVENT_JSON" | jq -r '.username')
TEXT=$(echo "$EVENT_JSON" | jq -r '.text')
CREATED_AT=$(echo "$EVENT_JSON" | jq -r '.created_at')
URL=$(echo "$EVENT_JSON" | jq -r '.url')
MEDIA=$(echo "$EVENT_JSON" | jq -r '.media | length')

echo ""
echo "Tweet ID: $TWEET_ID"
echo "Username: $USERNAME"
echo "Text: $TEXT"
echo "Created: $CREATED_AT"
echo "URL: $URL"
echo "Media count: $MEDIA"

# Check for duplicate
echo ""
echo "=== Checking for duplicates ==="
mkdir -p memory
if grep -q "^$TWEET_ID$" memory/x-trader-seen.txt 2>/dev/null; then
  echo "DUPLICATE: This tweet was already processed. Exiting."
  exit 0
else
  echo "New tweet, proceeding..."
  echo "$TWEET_ID" >> memory/x-trader-seen.txt
fi

# Step 2: Load context
echo ""
echo "=== Step 2: Load context ==="
if [ -f "memory/topics/traders.md" ]; then
  echo "Found traders.md"
  grep -A 5 "^## @$USERNAME" memory/topics/traders.md 2>/dev/null || echo "No existing context for @$USERNAME"
fi

# Step 3: Cross-platform dedup (only for Chase, Killa, HCH)
echo ""
echo "=== Step 3: Cross-platform dedup ==="
DUAL_PLATFORM=("Crypto_Chase" "KillaXBT" "HeartCanHodl")
IS_DUAL=0
for trader in "${DUAL_PLATFORM[@]}"; do
  if [ "$USERNAME" = "$trader" ]; then
    IS_DUAL=1
    break
  fi
done
echo "Is dual-platform trader: $IS_DUAL"

# Step 4: Classify
echo ""
echo "=== Step 4: Classify ==="

# HR-1: Test tweets
if echo "$TEXT" | grep -iE 'test|testing' >/dev/null; then
  echo "Classification: NON-FINANCIAL (test tweet) - SKIP"
  echo "$TWEET_ID" >> memory/x-trader-seen.txt
  exit 0
fi

# Check if it's personal action
if echo "$TEXT" | grep -iE "just (longed|shorted|bought|sold|added|took profit|cancelled|filled|placed)" >/dev/null; then
  echo "Classification: PERSONAL ACTION DETECTED"
  echo "Text suggests: $TEXT"
else
  echo "Classification: OPINION/INFORMATIONAL"
fi

# Step 5-6: Determine alert type
echo ""
echo "=== Alert Decision ==="
echo "Text: \"$TEXT\""
echo "This appears to be: $USERNAME saying 'Faded? @Evan_ss6'"
echo "Classification: AMBIGUOUS/CRYPTIC - requires context"

# Step 8: Update memory
echo ""
echo "=== Step 8: Update memory ==="
mkdir -p memory/topics memory/logs
TODAY=$(date +%Y-%m-%d)

# Append to traders.md
if [ ! -f "memory/topics/traders.md" ]; then
  cat > "memory/topics/traders.md" << 'EOF'
# Traders Memory
EOF
fi

# Check if trader section exists, if not create it
if ! grep -q "^## @$USERNAME" memory/topics/traders.md; then
  cat >> memory/topics/traders.md << EOF

## @$USERNAME
**Current open positions:** TBD
**Recent thesis:** TBD
**Calibration:** First contact
**Last seen:** $CREATED_AT
**Events (rolling):**
EOF
fi

# Append event line
echo "  - $(date -d "$CREATED_AT" '+%b %d %H:%MZ' 2>/dev/null || echo "Jul 24 18:42Z") — ambiguous: unclear "$TWEET_ID"" >> memory/topics/traders.md

# Step 9: Log entry
cat >> "memory/logs/$TODAY.md" << EOF

### x-trader-monitor (real-time event)
- trader: @$USERNAME
- tweet_id: $TWEET_ID
- classification: ambiguous
- ticker(s): [none detected]
- alerted: yes (calibration)
- notes: Cryptic message "Faded? @Evan_ss6" - context required from existing position/conversation

EOF

echo "Memory updated."
echo ""
echo "=== Summary ==="
echo "Event processed for @$USERNAME"
echo "Classification: AMBIGUOUS - sending calibration alert"
