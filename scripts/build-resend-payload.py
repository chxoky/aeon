import json, os, sys

plain = open("/tmp/brief-plain.txt").read()
html = open("/tmp/brief-html.txt").read()

recipients_raw = os.environ.get("BRIEF_RECIPIENTS", "")
recipients = [r.strip() for r in recipients_raw.split(",") if r.strip()] if recipients_raw else []

if not recipients:
    print("BRIEF_RECIPIENTS not set — skipping email", file=sys.stderr)
    sys.exit(0)

payload = {
    "from": "Aeon Briefings <onboarding@resend.dev>",
    "to": recipients,
    "subject": "[Aeon] Morning Brief — 2026-08-01",
    "html": html,
    "text": plain
}

with open("/tmp/resend-payload.json", "w") as f:
    json.dump(payload, f)

print("ok")
