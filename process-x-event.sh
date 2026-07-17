#!/bin/bash
set -e

# Process X/Twitter trader event
TWEET_ID="2078189721327436194"
USERNAME="t_in_crypto"
TWEET_TEXT="@Trives_ Everything you need to find is easy! Several values ​​and dates are in plain sight"
CREATED_AT="Fri Jul 17 18:46:55 +0000 2026"
URL="https://x.com/t_in_crypto/status/2078189721327436194"

TODAY=$(date +%Y-%m-%d)
LOG_DIR="memory/logs"
mkdir -p "$LOG_DIR"

# Step 1: Check for duplicate
echo "[*] Checking for duplicate processing..."
if [ -f memory/x-trader-seen.txt ]; then
  if grep -q "^${TWEET_ID}$" memory/x-trader-seen.txt; then
    echo "X_TRADER_DUPLICATE: Tweet $TWEET_ID already processed"
    exit 0
  fi
fi

# Step 2: Load trader context
echo "[*] Loading trader context from memory/topics/traders.md..."
TRADER_SECTION=$(grep -A 20 "^## @${USERNAME}" memory/topics/traders.md 2>/dev/null || echo "")

if [ -z "$TRADER_SECTION" ]; then
  echo "[!] Trader @${USERNAME} not found in traders.md - treating as new watcher"
fi

# Step 3: Classify the post
echo "[*] Classifying tweet..."
echo "Tweet: $TWEET_TEXT"

# Check for test tweets (HR-1)
if echo "$TWEET_TEXT" | grep -qi "test"; then
  echo "[CLASSIFICATION] Non-financial (test tweet) - HR-1 applies"
  CLASSIFICATION="skip"
  ALERT="no"
else
  # Check if this looks like a personal action (trade signal)
  if echo "$TWEET_TEXT" | grep -qEi "just (longed|shorted|entered|filled|took profit|added|closed)|cancelled|market order|limit order"; then
    CLASSIFICATION="trade-new-entry"
    ALERT="yes"
    echo "[CLASSIFICATION] Trade signal detected"
  else
    # It's cryptic/unclear with references to "values and dates"
    # This looks like it could be a puzzle or hint, not a clear financial signal
    if echo "$TWEET_TEXT" | grep -qE "everything.*easy|values.*dates|plain sight"; then
      CLASSIFICATION="ambiguous"
      ALERT="yes"
      echo "[CLASSIFICATION] Cryptic/ambiguous - needs clarification"
    else
      CLASSIFICATION="informational"
      ALERT="yes"
      echo "[CLASSIFICATION] Informational"
    fi
  fi
fi

echo ""
echo "=== RESULT ==="
echo "Trader: @${USERNAME}"
echo "Tweet ID: ${TWEET_ID}"
echo "Classification: ${CLASSIFICATION}"
echo "Alert: ${ALERT}"
echo ""

# Step 4: Record seen ID
echo "$TWEET_ID" >> memory/x-trader-seen.txt
LINES=$(wc -l < memory/x-trader-seen.txt)
if [ "$LINES" -gt 5000 ]; then
  tail -2000 memory/x-trader-seen.txt > memory/x-trader-seen.tmp && mv memory/x-trader-seen.tmp memory/x-trader-seen.txt
fi

# Step 5: Log the event
LOG_FILE="${LOG_DIR}/${TODAY}.md"
if [ ! -f "$LOG_FILE" ]; then
  echo "# Activity Log — $TODAY" > "$LOG_FILE"
fi

cat >> "$LOG_FILE" << EOF

### x-trader-monitor (real-time event)
- trader: @${USERNAME}
- tweet_id: ${TWEET_ID}
- classification: ${CLASSIFICATION}
- ticker(s): [none identified]
- alerted: ${ALERT}
- notes: Cryptic message from ${USERNAME} referencing "values and dates" in plain sight, likely a puzzle/hint rather than actionable trade signal
EOF

echo "[✓] Logged to ${LOG_FILE}"

# Step 6: Send alert if needed
if [ "$ALERT" = "yes" ]; then
  if [ "$CLASSIFICATION" = "ambiguous" ]; then
    echo ""
    echo "[ALERT] Sending calibration alert for ambiguous message..."
    ALERT_MSG="🔍 *Calibration — @${USERNAME}*

\`\`\`
${TWEET_TEXT}
\`\`\`

Unable to classify — what's your read?"
    ./notify "$ALERT_MSG"
    echo "[✓] Alert sent"
  else
    echo "[*] Classification '$CLASSIFICATION' requires further handling - skipping auto-alert"
  fi
else
  echo "[*] No alert needed - classification: $CLASSIFICATION"
fi

echo ""
echo "[✓] Processing complete"
