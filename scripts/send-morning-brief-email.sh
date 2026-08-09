#!/usr/bin/env bash
# Helper: send morning brief via Resend API using secretcurl
# Called by morning-brief skill. Uses {RESEND_API_KEY} placeholder pattern.
set -e

SUBJECT="$1"
HTML_FILE="$2"
TEXT_FILE="$3"

if [ -z "$BRIEF_RECIPIENTS" ]; then
  echo "ERROR: BRIEF_RECIPIENTS not set — skipping email"
  exit 1
fi

HTML=$(cat "$HTML_FILE")
PLAIN=$(cat "$TEXT_FILE")

# Build to array from comma-separated BRIEF_RECIPIENTS
TO_ARRAY=$(echo "$BRIEF_RECIPIENTS" | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | \
  python3 -c "import sys, json; print(json.dumps([l.strip() for l in sys.stdin if l.strip()]))" 2>/dev/null || \
  echo "[\"$BRIEF_RECIPIENTS\"]")

PAYLOAD=$(printf '%s' "{\"from\":\"Aeon Briefings <onboarding@resend.dev>\",\"to\":$TO_ARRAY,\"subject\":\"$SUBJECT\",\"html\":$(python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))" <<< "$HTML"),\"text\":$(python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))" <<< "$PLAIN")}")

./secretcurl -s -X POST https://api.resend.com/emails \
  -H "Authorization: Bearer {RESEND_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD"
