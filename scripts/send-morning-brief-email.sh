#!/bin/bash
# Send morning brief email via Resend
# Skips silently if BRIEF_RECIPIENTS is unset or empty
set -e

if [ -z "${BRIEF_RECIPIENTS:-}" ]; then
  echo "BRIEF_RECIPIENTS not set — skipping email"
  exit 0
fi

python3 /home/runner/work/aeon/aeon/scripts/build-morning-brief-payload.py
if [ ! -f /tmp/morning-brief-payload.json ]; then
  echo "ERROR: payload file not created"
  exit 1
fi

echo "Sending morning brief email..."
RESPONSE=$(./secretcurl -s -w "\nHTTP_STATUS:%{http_code}" -X POST https://api.resend.com/emails \
  -H "Authorization: Bearer {RESEND_API_KEY}" \
  -H "Content-Type: application/json" \
  -d @/tmp/morning-brief-payload.json)

HTTP_STATUS=$(echo "$RESPONSE" | grep "HTTP_STATUS:" | cut -d: -f2)
BODY=$(echo "$RESPONSE" | grep -v "HTTP_STATUS:")

if [ "$HTTP_STATUS" = "200" ] || [ "$HTTP_STATUS" = "201" ]; then
  echo "Email sent successfully (HTTP $HTTP_STATUS): $BODY"
else
  echo "ERROR: Resend returned HTTP $HTTP_STATUS: $BODY"
  exit 1
fi
