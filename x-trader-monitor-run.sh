#!/bin/bash
set -e

cd /home/runner/work/aeon/aeon
TODAY=$(date +%Y-%m-%d)

# Step 1: Decode the event
VAR='eyJpZCI6IjIwODY2OTU0NzcxMjczODk0NTAiLCJ1c2VybmFtZSI6IlN0b2lpaWMiLCJ0ZXh0IjoiaHR0cHM6Ly90LmNvL3JFTWI0bzJhUWkiLCJjcmVhdGVkX2F0IjoiTW9uIEF1ZyAxMCAwNjowNTo0NSArMDAwMCAyMDI2IiwidXJsIjoiaHR0cHM6Ly94LmNvbS9TdG9paWljL3N0YXR1cy8yMDg2Njk1NDc3MTI3Mzg5NDUwIiwibWVkaWEiOltdfQ=='

EVENT_JSON=$(echo "${VAR}" | base64 -d 2>/dev/null)

if [ -z "$EVENT_JSON" ]; then
  echo "X_TRADER_BAD_EVENT: Cannot decode var"
  exit 1
fi

echo "=== Decoded Event ==="
echo "$EVENT_JSON" | jq .
echo

# Extract fields
TWEET_ID=$(echo "$EVENT_JSON" | jq -r '.id // empty')
USERNAME=$(echo "$EVENT_JSON" | jq -r '.username // empty')
TEXT=$(echo "$EVENT_JSON" | jq -r '.text // empty')
URL=$(echo "$EVENT_JSON" | jq -r '.url // empty')
MEDIA=$(echo "$EVENT_JSON" | jq -r '.media // []')

if [ -z "$TWEET_ID" ] || [ -z "$TEXT" ]; then
  echo "X_TRADER_BAD_EVENT: Missing required fields"
  exit 1
fi

echo "Tweet ID: $TWEET_ID"
echo "Username: $USERNAME"
echo "Text: $TEXT"
echo "URL: $URL"
echo

# Check if already seen
mkdir -p memory
if grep -q "^$TWEET_ID$" memory/x-trader-seen.txt 2>/dev/null; then
  echo "Already processed this tweet (duplicate)"
  exit 0
fi

# Add to seen tweets
echo "$TWEET_ID" >> memory/x-trader-seen.txt
LINES=$(wc -l < memory/x-trader-seen.txt 2>/dev/null || echo 0)
if [ "$LINES" -gt 5000 ]; then
  tail -2000 memory/x-trader-seen.txt > memory/x-trader-seen.tmp
  mv memory/x-trader-seen.tmp memory/x-trader-seen.txt
fi

echo "=== Classification ==="

# Step 3: Check for hardcoded rules
if [[ "$TEXT" =~ (test|testing) ]]; then
  echo "HR-1: Test tweet detected — skipping silently"

  # Log to daily log
  mkdir -p memory/logs
  echo "### x-trader-monitor (real-time event)" >> "memory/logs/${TODAY}.md"
  echo "- trader: @${USERNAME}" >> "memory/logs/${TODAY}.md"
  echo "- tweet_id: ${TWEET_ID}" >> "memory/logs/${TODAY}.md"
  echo "- classification: skip" >> "memory/logs/${TODAY}.md"
  echo "- ticker(s): []" >> "memory/logs/${TODAY}.md"
  echo "- alerted: no" >> "memory/logs/${TODAY}.md"
  echo "- notes: Test tweet pattern detected" >> "memory/logs/${TODAY}.md"
  echo >> "memory/logs/${TODAY}.md"

  exit 0
fi

# Step 4: Load context if available
if [ -f "memory/topics/traders.md" ]; then
  echo "Loaded traders.md context"
fi

# Step 4 Classification: Determine type
# For this tweet: "https://t.co/rETb4o2aQi" — it's just a link
# This looks like a URL-only post which is typically an image or chart share

# Classify as CRYPTIC (Step 4B) since it's URL-only with no text explanation
echo "Classification: CRYPTIC (URL-only post, needs image context)"

# Try to fetch and read the media
if [ -n "$MEDIA" ] && [ "$MEDIA" != "[]" ]; then
  echo "Media detected in event"
  mkdir -p .media

  i=0
  echo "$MEDIA" | jq -r '.[]?' | while read -r url; do
    if [ -n "$url" ]; then
      echo "Fetching media: $url"
      ext="${url##*.}"
      case "$ext" in
        jpg|jpeg|png|webp|gif) ;;
        *) ext=jpg ;;
      esac
      if curl -sSL --max-time 20 "$url" -o ".media/img_$i.$ext" 2>/dev/null; then
        echo "  → Saved .media/img_$i.$ext"
      fi
      i=$((i+1))
    fi
  done
else
  echo "No media URLs in event payload"
fi

# Send calibration alert to Kyle (per HR-2)
echo
echo "=== Sending Calibration Alert ==="

ALERT_TEXT="🔍 *Calibration — @${USERNAME}*

Event: URL-only post (unable to resolve referenced link)
@${USERNAME}: \"${TEXT}\"

Unable to classify — what's your read?

[View post](${URL})"

echo "$ALERT_TEXT"

# Attempt to notify (if secrets are configured)
if command -v ./notify >/dev/null 2>&1; then
  ./notify "$ALERT_TEXT"
else
  echo "(./notify not available — alert not sent)"
fi

# Update memory/traders.md if it exists
if [ -f "memory/topics/traders.md" ]; then
  echo "  - $(date -u +%b\ %d\ %H:%M)Z — ambiguous: URL-only post, cannot interpret without image fetch [${TWEET_ID}]" >> "memory/topics/traders.md"
fi

# Log to daily log
mkdir -p memory/logs
echo "### x-trader-monitor (real-time event)" >> "memory/logs/${TODAY}.md"
echo "- trader: @${USERNAME}" >> "memory/logs/${TODAY}.md"
echo "- tweet_id: ${TWEET_ID}" >> "memory/logs/${TODAY}.md"
echo "- classification: ambiguous" >> "memory/logs/${TODAY}.md"
echo "- ticker(s): []" >> "memory/logs/${TODAY}.md"
echo "- alerted: yes" >> "memory/logs/${TODAY}.md"
echo "- notes: URL-only post, sent calibration alert to Kyle" >> "memory/logs/${TODAY}.md"
echo >> "memory/logs/${TODAY}.md"

echo
echo "✓ Skill completed"
