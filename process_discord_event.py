#!/usr/bin/env python3

import base64
import json
import sys
from datetime import datetime
import os

# Decode the event
var = "eyJpZCI6IjE1NDk2Nzg2OTk2MzEzNTM5NDYiLCJjaGFubmVsX2lkIjoiMTM5MzEzNzA1MTEwODUwNzcyOCIsInVzZXJuYW1lIjoiaGVhcnRjYW5ob2RsIiwiY29udGVudCI6IndlIGFyZSB0cnlpbmcgb3VyIGxvbmcgbHVjayBjbG9zZXIgdG8gdGhhdCB+NzRrIGFyZWEiLCJjcmVhdGVkX2F0IjoiMjAyNi0wOS0xNlQwNzowOTo1My42MzAwMDArMDA6MDAiLCJpc19yZXBseSI6dHJ1ZSwicmVmZXJlbmNlZF9tZXNzYWdlIjp7InVzZXJuYW1lIjoiaGVhcnRjYW5ob2RsIiwiY29udGVudCI6ImltcG9ydGFudCBodGYgcmUtdGVzdCBpcyBhdCA3NGsgJEJUQyJ9LCJhdHRhY2htZW50cyI6W10sImZhc3RfcGF0aF9hbGVydGVkIjp0cnVlfQ=="

try:
    event_json = base64.b64decode(var).decode()
    event = json.loads(event_json)
    print("✓ Event decoded successfully")
    print(f"\nEvent details:")
    print(json.dumps(event, indent=2))
except Exception as e:
    print(f"✗ DISCORD_TRADER_BAD_EVENT: {var}")
    sys.exit(1)

# Validate required fields
if not event.get("content") and not event.get("attachments"):
    print(f"✗ DISCORD_TRADER_BAD_EVENT: Empty content and no attachments")
    sys.exit(1)

# Step 1: Check fast-path alert
fast_path_alerted = event.get("fast_path_alerted", False)
print(f"\n[Fast-path check] alerted: {fast_path_alerted}")

# Step 2: Load channel mapping
with open("memory/discord-channels.json") as f:
    channels_data = json.load(f)

channel_id = event["channel_id"]
channel_labels = channels_data["channel_labels"]
traders_info = channels_data["traders"]

# Get label
label = channel_labels.get(channel_id, f"Unknown-{channel_id}")
print(f"[Channel] {channel_id} → {label}")

# Resolve trader
username = event["username"].lower()
trader_name = None
is_primary = False

for trader, info in traders_info.items():
    if info["discord_username"].lower() == username:
        trader_name = trader
        # Check if primary channel
        if channel_id in info["channels"].get("primary", []):
            is_primary = True
        break

if not trader_name:
    print(f"✗ Unknown trader username: {username}")
    sys.exit(1)

print(f"[Trader] {trader_name} ({username}) — {'primary' if is_primary else 'supporting'} channel")

# Step 3: Check if already seen
message_id = event["id"]
seen_file = "memory/discord-trader-seen.txt"

if os.path.exists(seen_file):
    with open(seen_file) as f:
        seen_ids = set(line.strip() for line in f)
else:
    seen_ids = set()

if message_id in seen_ids:
    print(f"✓ Message already processed (dedup)")
    sys.exit(0)

# Step 4: Parse message content
content = event.get("content", "").strip()
is_reply = event.get("is_reply", False)
referenced = event.get("referenced_message")

print(f"\n[Message] {'Reply' if is_reply else 'Original'} — {len(content)} chars")
if is_reply and referenced:
    print(f"  Replying to {referenced.get('username')}: \"{referenced.get('content')[:80]}...\"")
print(f"  Content: \"{content}\"")

# Step 5: Classify the message
# Check for test patterns (HR-1)
test_patterns = ["test", "testing"]
if any(pattern in content.lower() for pattern in test_patterns):
    classification = "skip-test"
    print(f"\n[HR-1] Test message — skip silently")
elif "74k" in content.lower() or "btc" in content.lower():
    # This is about BTC price levels/technical analysis
    # "we are trying our long luck closer to that ~74k area" is informational
    if "trying" in content.lower() or "long" in content.lower():
        classification = "informational-position-update"
        print(f"\n[Classification] informational-position-update — BTC position conviction")
    else:
        classification = "informational-technical"
        print(f"\n[Classification] informational-technical — BTC level analysis")
else:
    classification = "informational"
    print(f"\n[Classification] informational — no trade execution")

# Determine ticker
tickers = []
if "btc" in content.lower() or "bitcoin" in content.lower():
    tickers.append("BTC")
print(f"[Tickers] {tickers if tickers else 'None'}")

# Step 6: Alert decision
should_alert = False  # fast_path_alerted=true, so skip Telegram
alert_status = "fast-path"
print(f"\n[Alert] Skipping — {alert_status}")

# Step 7: Update memory - add to seen list
print(f"\n[Memory] Updating discord-trader-seen.txt...")
with open(seen_file, "a") as f:
    f.write(f"{message_id}\n")

# Prune if needed
with open(seen_file) as f:
    lines = f.readlines()
if len(lines) > 5000:
    with open(seen_file, "w") as f:
        f.writelines(lines[-2000:])
    print(f"  Pruned to 2000 entries")

# Step 8: Log the event
log_date = datetime.now().strftime("%Y-%m-%d")
log_file = f"memory/logs/{log_date}.md"

log_entry = f"""### discord-trader-monitor (real-time event)
- trader: {trader_name}
- channel: {channel_id} ({label}) — {'primary' if is_primary else 'supporting'}
- message_id: {message_id}
- classification: {classification}
- ticker(s): {', '.join(tickers) if tickers else 'none'}
- alerted: {alert_status}
- notes: Discord reply to own prior message; conviction/position update on BTC 74k level
"""

if os.path.exists(log_file):
    with open(log_file, "a") as f:
        f.write("\n" + log_entry)
else:
    with open(log_file, "w") as f:
        f.write(log_entry)

print(f"[Logging] {log_file}")
print(f"\n✓ Event processed successfully")
print(f"  Classification: {classification}")
print(f"  Alert: {alert_status}")
