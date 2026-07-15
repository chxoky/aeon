#!/usr/bin/env bash
for v in RESEND_API_KEY BRIEF_RECIPIENTS TELEGRAM_BOT_TOKEN SENDGRID_API_KEY NOTIFY_EMAIL_TO DISCORD_WEBHOOK_URL SLACK_WEBHOOK_URL; do
  if [ -n "${!v:-}" ]; then echo "$v: SET"; else echo "$v: unset"; fi
done
