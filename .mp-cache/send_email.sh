#!/usr/bin/env bash
# Self-contained morning-brief emailer. Reads RESEND_API_KEY + BRIEF_RECIPIENTS
# from env internally (secret never appears on the caller's command line).
set -euo pipefail
KEY="${RESEND_API_KEY:-}"
RECIP="${BRIEF_RECIPIENTS:-}"
if [ -z "$KEY" ]; then echo "EMAIL_SKIPPED: RESEND_API_KEY unset"; exit 0; fi
if [ -z "$RECIP" ]; then echo "EMAIL_SKIPPED: BRIEF_RECIPIENTS unset"; exit 0; fi

HTML=$(cat .mp-cache/brief.html)
TEXT=$(cat .mp-cache/brief.txt)

# Build the "to" JSON array from a comma-separated list.
TO=$(printf '%s' "$RECIP" | tr ',' '\n' | sed 's/^ *//;s/ *$//' | grep -v '^$' \
  | jq -R . | jq -s .)

PAYLOAD=$(jq -n \
  --argjson to "$TO" \
  --arg subject "[Aeon] Morning Brief — 2026-07-18" \
  --arg html "$HTML" \
  --arg text "$TEXT" \
  '{from:"Aeon Briefings <onboarding@resend.dev>", to:$to, subject:$subject, html:$html, text:$text}')

RESP=$(curl -s -X POST "https://api.resend.com/emails" \
  -H "Authorization: Bearer $KEY" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD")
echo "RESEND_RESPONSE: $RESP"
