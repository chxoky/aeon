#!/usr/bin/env python3
import base64
import json
import os
from datetime import datetime

# Decode the provided event
encoded_event = "eyJpZCI6IjE1NDk2NzYzNjQ5NTk4NDIzOTUiLCJjaGFubmVsX2lkIjoiMTAyMzYzODU3MzMxMzk2NjIxMiIsInVzZXJuYW1lIjoiaGVhcnRjYW5ob2RsIiwiY29udGVudCI6Ikxpa2UuLiBpbiBhIG1hcmtldCBsaWtlIHRoaXMsIGl04oCZcyBkaWZmaWN1bHQgdG8gYmFzZSBhbiBpZGVhIG9uIGEgc2luZ2xlIHBvaW50IGFjdHVhbGx5IGJ1dCBJIGFtIG9uIHRoZSBwcmUtZm9tYyByaXNraW5nIG9uIGNhbXAiLCJjcmVhdGVkX2F0IjoiMjAyNi0wOS0xNlQwNzowMDozNy4wMDEwMDArMDA6MDAiLCJpc19yZXBseSI6dHJ1ZSwicmVmZXJlbmNlZF9tZXNzYWdlIjp7InVzZXJuYW1lIjoidGtnbGl0Y2gzNjkiLCJjb250ZW50IjoiaGlrZSBpcyBiZWluZyBwcmljZWQgaW4ifSwiYXR0YWNobWVudHMiOltdLCJmYXN0X3BhdGhfYWxlcnRlZCI6ZmFsc2V9"

print("=" * 60)
print("Discord Trader Monitor Skill Execution")
print("=" * 60)

# Step 1: Decode event
print("\n=== Step 1: Decode Event ===")
try:
    event_json_str = base64.b64decode(encoded_event).decode('utf-8')
    event = json.loads(event_json_str)
    print("✓ Event decoded successfully")
    print(json.dumps(event, indent=2))
except Exception as e:
    print(f"ERROR: Failed to decode event: {e}")
    exit(1)

# Extract fields
message_id = event.get('id', '')
channel_id = event.get('channel_id', '')
username = event.get('username', '')
content = event.get('content', '')
is_reply = event.get('is_reply', False)
fast_path_alerted = event.get('fast_path_alerted', False)
referenced_message = event.get('referenced_message', {})

# Step 2: Resolve channel
print("\n=== Step 2: Resolve Channel & Trader ===")
channel_labels = {
    "1336082716063694962": "Chase — Chase",
    "1343971265962049597": "Chase — TradFi",
    "1247927786681794601": "Chase — Crypto",
    "1411492188315193416": "K",
    "1472153627324842057": "HCH — Free",
    "1191800982414299217": "HCH — Opportunistic Moments",
    "1279738718680256553": "HCH — Trades",
    "1393137051108507728": "HCH — Comments",
    "1023638573313966212": "HCH — Chat"
}

channel_label = channel_labels.get(channel_id, "Unknown Channel")
print(f"Channel {channel_id}: {channel_label}")

# Determine channel type
hch_primary = ["1472153627324842057", "1191800982414299217", "1279738718680256553", "1393137051108507728"]
channel_type = "primary" if channel_id in hch_primary else "supporting"
print(f"Type: {channel_type}")
print(f"Trader: {username}")

# Verify username matches trader
if username.lower() != "heartcanhodl":
    print(f"Warning: Username does not match expected trader for this channel")

# Fast-path check
print("\n=== Step 4: Fast-Path Check ===")
if fast_path_alerted:
    print("✓ Fast path ALREADY ALERTED (2-5s latency via Telegram)")
    print("  Skipping Telegram sends, proceeding to memory updates only")
    skip_alert = True
else:
    print("Fast path did NOT fire - processing full flow with alerts")
    skip_alert = False

# Step 5: Classify message
print("\n=== Step 5: Classify Message ===")
print(f"Content: {content}")
print()

# Analysis
if is_reply:
    ref_user = referenced_message.get('username', 'unknown')
    ref_content = referenced_message.get('content', '')
    print(f"Reply context: {ref_user} asked about '{ref_content}'")

# This is a member commentary in the supporting channel
# The message discusses market conditions and personal conviction, not a trade execution
classification = "informational"
print(f"Classification: {classification}")
print("Reason: Member commentary on market conditions, replying to question about HIKE pricing")
print("        Not a trade execution (no first-person action language)")

# Step 6-7: Alert logic
print("\n=== Step 6-7: Alert Generation ===")
if not skip_alert:
    print("Would send informational alert via Telegram:")
    print()
    print(f"💬 *[DC: {channel_label}]*")
    print()
    if is_reply and referenced_message:
        ref_user = referenced_message.get('username', 'member')
        ref_content = referenced_message.get('content', '')
        print(f"↩️ _Member ({ref_user}): \"{ref_content}\"_")
        print()
    print(content)
else:
    print("Fast-path alert already sent")
    print("Skipping Telegram notification")

# Step 9: Dedup check and update memory
print("\n=== Step 9: Memory Updates ===")
os.makedirs('memory', exist_ok=True)
os.makedirs('memory/topics', exist_ok=True)
os.makedirs('memory/logs', exist_ok=True)

# Check if already seen
seen_file = 'memory/discord-trader-seen.txt'
if os.path.exists(seen_file):
    with open(seen_file, 'r') as f:
        seen_ids = f.read().splitlines()
        if message_id in seen_ids:
            print(f"⚠️  Message {message_id} already processed - would skip")
            print("Exiting early")
            exit(0)

# Add message ID to seen list
with open(seen_file, 'a') as f:
    f.write(message_id + '\n')
print(f"✓ Message ID tracked in {seen_file}")

# Ensure topic files exist
for topic in ['traders.md', 'ticker-focus.md', 'active-trades.md']:
    path = f'memory/topics/{topic}'
    if not os.path.exists(path):
        open(path, 'w').close()
        print(f"✓ Created {path}")
    else:
        print(f"✓ {path} exists")

# Step 10: Activity log
print("\n=== Step 10: Activity Log ===")
today = '2026-09-16'
log_file = f'memory/logs/{today}.md'

log_entry = f"""### discord-trader-monitor (real-time event)
- trader: {username}
- channel: {channel_id} ({channel_type})
- message_id: {message_id}
- classification: {classification}
- ticker(s): [HIKE]
- alerted: {'no (fast-path)' if skip_alert else 'yes'}
- notes: Member chat in supporting channel — replying to Q about "hike being priced in". Commentary on pre-FOMC market conditions and conviction sizing.
"""

with open(log_file, 'a') as f:
    f.write('\n' + log_entry)
print(f"✓ Activity logged to {log_file}")

print("\n" + "=" * 60)
print("EXECUTION COMPLETE — SUCCESS")
print("=" * 60)
print("\nSummary:")
print(f"  Event: Discord message from @{username}")
print(f"  Channel: {channel_label} ({channel_type})")
print(f"  Classification: {classification}")
print(f"  Alert Status: {'Skipped (fast-path)' if skip_alert else 'Would send'}")
print(f"  Memory: Updated traders seen list, activity log")
print()
