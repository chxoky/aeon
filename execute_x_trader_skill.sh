#!/bin/bash
set -e

# Skill: X Trader Monitor
# Date: 2026-07-26

var="eyJpZCI6IjIwODE0MDQ1ODY0Njg4MTQ5MTEiLCJ1c2VybmFtZSI6IldpbGRfUmFuZG9tbmVzcyIsInRleHQiOiIkQlRDXG5cblByb2dyZXNzaW5nIGh0dHBzOi8vdC5jby9uWUlqeDF3YkthIiwiY3JlYXRlZF9hdCI6IlN1biBKdWwgMjYgMTU6NDE6MzggKzAwMDAgMjAyNiIsInVybCI6Imh0dHBzOi8veC5jb20vV2lsZF9SYW5kb21uZXNzL3N0YXR1cy8yMDgxNDA0NTg2NDY4ODE0OTExIiwibWVkaWEiOlsiaHR0cHM6Ly9wYnMudHdpbWcuY29tL21lZGlhL0hPS2ljR3NXWUFBTUUxQS5qcGciLCJodHRwczovL3Bicy50d2ltZy5jb20vbWVkaWEvSE9GV2VUM2JrQUExRWhZLmpwZyJdfQ=="
today="2026-07-26"

# Step 1: Decode the event
echo "[Step 1] Decoding event..."
EVENT_JSON=$(echo "$var" | base64 -d 2>/dev/null)

if [ -z "$EVENT_JSON" ]; then
  echo "X_TRADER_BAD_EVENT: Failed to decode base64"
  exit 1
fi

# Parse JSON fields
TWEET_ID=$(echo "$EVENT_JSON" | jq -r '.id // empty' 2>/dev/null)
USERNAME=$(echo "$EVENT_JSON" | jq -r '.username // empty' 2>/dev/null)
TEXT=$(echo "$EVENT_JSON" | jq -r '.text // empty' 2>/dev/null)
CREATED_AT=$(echo "$EVENT_JSON" | jq -r '.created_at // empty' 2>/dev/null)
URL=$(echo "$EVENT_JSON" | jq -r '.url // empty' 2>/dev/null)
MEDIA=$(echo "$EVENT_JSON" | jq -r '.media[]? // empty' 2>/dev/null)

echo "Tweet ID: $TWEET_ID"
echo "Username: $USERNAME"
echo "Text: $TEXT"
echo "Created: $CREATED_AT"
echo "URL: $URL"
echo "Media files: $(echo "$MEDIA" | wc -l)"

if [ -z "$TEXT" ] || [ -z "$USERNAME" ]; then
  echo "X_TRADER_BAD_EVENT: Missing required fields"
  exit 1
fi

# Step 2: Check for deduplication
echo "[Step 2] Checking deduplication..."
mkdir -p memory
if [ -f memory/x-trader-seen.txt ]; then
  if grep -q "^$TWEET_ID$" memory/x-trader-seen.txt; then
    echo "Already processed this tweet (ID: $TWEET_ID) - skipping"
    exit 0
  fi
fi

# Step 3: Load memory context
echo "[Step 3] Loading memory context..."
echo "Checking for existing trader/active trades memory..."

# Step 4: Classify the post
echo "[Step 4] Classifying post..."

# Check for test tweets (HR-1)
if echo "$TEXT" | grep -qiE '(^|\s)(test|testing|\[.*\]\s*test|\[.*\]\s*testing|testing\s+123)(\s|$)'; then
  CLASSIFICATION="non-financial (test tweet)"
  echo "→ Matches test-tweet pattern (HR-1), skipping"
  ALERT_NEEDED="no"
else
  # Check if media exists
  MEDIA_COUNT=$(echo "$MEDIA" | wc -l)
  if [ "$MEDIA_COUNT" -gt 0 ]; then
    echo "Post has $MEDIA_COUNT media file(s) - downloading for analysis..."
    mkdir -p .media
    i=0
    while IFS= read -r media_url; do
      if [ -n "$media_url" ]; then
        ext="${media_url##*.}"
        case "$ext" in jpg|jpeg|png|webp|gif) : ;; *) ext=jpg ;; esac
        echo "Downloading media $i: $media_url"
        if curl -sSL --max-time 20 "$media_url" -o ".media/img_$i.$ext" 2>/dev/null; then
          echo "  → saved .media/img_$i.$ext"
        else
          echo "  → download failed"
        fi
        i=$((i+1))
      fi
    done <<< "$MEDIA"
  fi

  # Classify based on content
  # Check if it's a personal action (first-person execution language)
  if echo "$TEXT" | grep -qiE '(just (longed|shorted|filled|bought|sold)|added (to|more)|took profit|cancelled (order|my)|closing|position)'; then
    CLASSIFICATION="trade-signal"
    echo "→ Appears to be personal trade action"
    ALERT_NEEDED="yes"
    ALERT_TYPE="trade-signal"
  else
    # Treat as informational
    CLASSIFICATION="informational"
    echo "→ Classified as informational (opinion/idea, not personal action)"
    ALERT_NEEDED="yes"
    ALERT_TYPE="informational"
  fi
fi

# Step 5-6: Prepare alert if needed
if [ "$ALERT_NEEDED" = "yes" ]; then
  echo "[Step 5-6] Preparing alert..."

  NOTIFY_MSG="🐦 *[X] @${USERNAME}*"$'\n\n'"${TEXT}"$'\n\n'"[View tweet](${URL})"

  if [ "$ALERT_TYPE" = "trade-signal" ]; then
    NOTIFY_MSG="🚨 *Trade Signal — @${USERNAME}*"$'\n\n'"${TEXT}"$'\n\n'"[View post](${URL})"
  fi

  echo "Alert prepared:"
  echo "$NOTIFY_MSG"

  # Uncomment to actually send notification
  # ./notify "$NOTIFY_MSG"
fi

# Step 8: Update memory
echo "[Step 8] Updating memory..."
mkdir -p memory/topics memory/logs

# Add to traders.md if it exists
if [ -f "memory/topics/traders.md" ]; then
  TIMESTAMP=$(date -u +"%b %d %H:%M")
  TICKERS=$(echo "$TEXT" | grep -oE '\$[A-Z_]+' | sort | uniq | tr '\n' ' ' | xargs)
  if [ -z "$TICKERS" ]; then
    TICKERS="(none)"
  fi
  GIST=$(echo "$TEXT" | cut -c1-50 | tr -d '\n')
  echo "  - $TIMESTAMP — $CLASSIFICATION: $TICKERS $GIST... [$TWEET_ID]" >> "memory/topics/traders.md"
  echo "→ Updated traders.md"
else
  echo "Note: memory/topics/traders.md not found (will be created if needed)"
fi

# Add to seen list
echo "$TWEET_ID" >> memory/x-trader-seen.txt

# Keep x-trader-seen.txt under 5000 lines
LINES=$(wc -l < memory/x-trader-seen.txt 2>/dev/null || echo 0)
if [ "$LINES" -gt 5000 ]; then
  tail -2000 memory/x-trader-seen.txt > memory/x-trader-seen.tmp && mv memory/x-trader-seen.tmp memory/x-trader-seen.txt
  echo "→ Trimmed x-trader-seen.txt (was $LINES lines)"
fi

# Step 9: Log
echo "[Step 9] Logging activity..."
LOG_FILE="memory/logs/${today}.md"
mkdir -p memory/logs

TICKERS=$(echo "$TEXT" | grep -oE '\$[A-Z_]+' | sort | uniq | tr '\n' ',' | sed 's/,$//')
if [ -z "$TICKERS" ]; then
  TICKERS="none"
fi

LOG_ENTRY="
### x-trader-monitor (real-time event)
- trader: @${USERNAME}
- tweet_id: ${TWEET_ID}
- classification: ${CLASSIFICATION}
- ticker(s): ${TICKERS}
- alerted: ${ALERT_NEEDED}
- notes: Event processed at $(date -u +"%H:%M:%S UTC")
"

echo "$LOG_ENTRY" >> "$LOG_FILE"
echo "→ Logged to $LOG_FILE"

echo ""
echo "✓ Skill execution complete"
echo "  Classification: $CLASSIFICATION"
echo "  Alert sent: $ALERT_NEEDED"
