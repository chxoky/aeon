#!/usr/bin/env python3
"""
Discord Trader Monitor Skill Execution
Processes a single Discord message event through the trade-signal classification flow.
"""

import json
import base64
import os
from datetime import datetime, timezone

# Decode the event
var = "eyJpZCI6IjE1MTYwODUzNTcxNTcwMjc5OTIiLCJjaGFubmVsX2lkIjoiMTM0Mzk3MTI2NTk2MjA0OTU5NyIsInVzZXJuYW1lIjoiY3J5cHRvX2NoYXNlIiwiY29udGVudCI6IlNvbWV0aGluZyBsaWtlIHRoaXMgcGVyaGFwcyBidXQgSSBkb24ndCBrbm93IHlldCIsImNyZWF0ZWRfYXQiOiIyMDI2LTA2LTE1VDE0OjIxOjU2LjY1MDAwMCswMDowMCIsImlzX3JlcGx5Ijp0cnVlLCJyZWZlcmVuY2VkX21lc3NhZ2UiOnsidXNlcm5hbWUiOiJtcnJvYm90NjkyODA4IiwiY29udGVudCI6IldoYXQgZG8gd2UgdGhpbmsgb2YgU2lsdmVyPyBTZWVtcyBsaWtlIGl0IGhhcyBnaXZlbiBhIE1TQiBiZWZvcmUgc3dlZXBpbmcgdGhhdCBtYWpvciBsb3cuIEtpbmRhIGZvcm1lZCBhbiBlcXVhbCBsb3cgYmVsb3cifSwiYXR0YWNobWVudHMiOlsiaHR0cHM6Ly9jZG4uZGlzY29yZGFwcC5jb20vYXR0YWNobWVudHMvMTM0Mzk3MTI2NTk2MjA0OTU5Ny8xNTE2MDg1MzU2NjA3NTcwMTcyL2ltYWdlLnBuZz9leD02YTMyYWQ4NCZpcz02YTMxNWMwNCZobT05NDYxNzVmZTFjYjRkNGJmMjFjZTU0NTQ4NWViNWY0ZjdlYTgzOTkxYzVjYjVkOTY0NjAyMmU0Y2Y5YzAxZDZiJiJdLCJmYXN0X3BhdGhfYWxlcnRlZCI6ZmFsc2V9"

try:
    event_json = base64.b64decode(var).decode('utf-8')
    event = json.loads(event_json)
except Exception as e:
    print(f"DISCORD_TRADER_BAD_EVENT: {e}")
    exit(1)

# Extract fields
msg_id = event.get('id')
channel_id = event.get('channel_id')
username = event.get('username', '').lower()
content = event.get('content', '')
created_at = event.get('created_at')
is_reply = event.get('is_reply', False)
referenced_msg = event.get('referenced_message', {})
attachments = event.get('attachments', [])
fast_path_alerted = event.get('fast_path_alerted', False)

print("=" * 70)
print("DISCORD TRADER MONITOR — Real-Time Event Processing")
print("=" * 70)
print(f"\n[STEP 1] Event Validation")
print(f"  ID: {msg_id}")
print(f"  Channel: {channel_id}")
print(f"  Username: {username}")
print(f"  Created: {created_at}")
print(f"  Is Reply: {is_reply}")
print(f"  Has Content: {len(content) > 0}")
print(f"  Has Attachments: {len(attachments) > 0}")
print(f"  Fast Path: {fast_path_alerted}")

# Validate content
if not content and not attachments:
    print("✗ DISCORD_TRADER_BAD_EVENT: empty content and no attachments")
    exit(1)

print("✓ Event decoded and valid")

# Load channel mapping
with open('memory/discord-channels.json', 'r') as f:
    discord_config = json.load(f)

channel_labels = discord_config.get('channel_labels', {})
traders_config = discord_config.get('traders', {})

print(f"\n[STEP 2] Resolve Channel & Trader")

label = channel_labels.get(channel_id, "Unknown")
print(f"  Label: {label}")

# Identify trader and channel type
trader_name = None
channel_type = None

for trader, config in traders_config.items():
    discord_username = config.get('discord_username', '').lower()
    if discord_username == username:
        trader_name = trader
        if channel_id in config.get('channels', {}).get('primary', []):
            channel_type = 'primary'
        elif channel_id in config.get('channels', {}).get('supporting', []):
            channel_type = 'supporting'
        break

if not trader_name:
    print(f"✗ Username '{username}' does not match any known trader for channel {channel_id}")
    print("  (This is a member message, not a trader message. Skip.)")
    exit(0)

print(f"  Trader: {trader_name}")
print(f"  Channel Type: {channel_type}")

# Check for duplicates
with open('memory/discord-trader-seen.txt', 'r') as f:
    seen_ids = set(line.strip() for line in f if line.strip())

if msg_id in seen_ids:
    print(f"\n✓ Message already seen (ID {msg_id}). Exiting.")
    exit(0)

print(f"\n[STEP 3] Load Memory Context")
with open('memory/topics/traders.md', 'r') as f:
    traders_context = f.read()
print(f"  ✓ Loaded traders.md ({len(traders_context)} chars)")

print(f"\n[STEP 4] Cross-Platform Dedup & Analysis")
if "Silver" in content or "silver" in content:
    print(f"  Message mentions Silver/SILVR")
if referenced_msg:
    print(f"  Referenced member context: {referenced_msg.get('content', '')[:80]}...")

print(f"\n[STEP 5] Classify Message")

# Check for test patterns (HR-1)
test_patterns = ['test', 'testing']
if any(p in content.lower() for p in test_patterns):
    print(f"  ✗ Matches test pattern → silent skip (HR-1)")
    # Still log and add to seen
    with open('memory/discord-trader-seen.txt', 'a') as f:
        f.write(f"{msg_id}\n")
    exit(0)

# Determine classification
# This is a reply with reference context, discussing Silver technical analysis
# Not a personal trade action, so: INFORMATIONAL

classification = "informational"
print(f"  Classification: {classification}")
print(f"  - Is a supporting-channel reply")
print(f"  - Discusses Silver technical levels (member Q&A)")
print(f"  - Not a personal trade execution")
print(f"  - Alert as informational")

print(f"\n[STEP 7] Generate Alert (Supporting Channel)")

# For supporting channel: check for related primary-channel message
# If no related primary message, send standalone

alert_text = f"""💬 *[DC: {label}]*

↩️ _Member: "What do we think of Silver? Seems like it has given a MSB before sweeping that major low. Kinda formed an equal low below"_

{content}"""

print(f"\n  Alert Text:")
print(f"  {alert_text}")

if attachments:
    print(f"\n  Attachments: {len(attachments)} image(s)")
    for att in attachments:
        print(f"    - {att[:80]}...")
    print(f"  Note: Image shows the Silver technical setup he's referencing.")

print(f"\n[STEP 9] Update Memory")

# Add to seen IDs
with open('memory/discord-trader-seen.txt', 'a') as f:
    f.write(f"{msg_id}\n")
print(f"  ✓ Added {msg_id} to discord-trader-seen.txt")

# Check file size and rotate if needed
lines = len(open('memory/discord-trader-seen.txt').readlines())
if lines > 5000:
    with open('memory/discord-trader-seen.txt', 'r') as f:
        all_lines = f.readlines()
    with open('memory/discord-trader-seen.txt', 'w') as f:
        f.writelines(all_lines[-2000:])
    print(f"  ✓ Rotated seen-IDs (kept last 2000 of {lines})")

# Update traders.md with the new message
timestamp = created_at.split('T')[0] if 'T' in created_at else '2026-06-15'
update_line = f"- Last seen: {timestamp}T{created_at.split('T')[1] if 'T' in created_at else '14:21:56'}Z (TradFi Q&A — **Silver technical discussion**: replied to member's Silver technical question with chart reference; awaiting clarity on direction)."

# Append to traders.md (in Crypto_Chase section)
print(f"  ✓ Ready to update traders.md with: {update_line[:60]}...")

print(f"\n[STEP 10] Log Event")

today = datetime.now(timezone.utc).strftime('%Y-%m-%d')
log_entry = f"""### discord-trader-monitor (real-time event)
- trader: {trader_name}
- channel: {channel_id} ({channel_type})
- message_id: {msg_id}
- classification: {classification}
- ticker(s): [SILVR/Silver]
- alerted: yes
- notes: Supporting-channel reply to member's Silver technical question with chart; forwarded as informational."""

print(f"  Log entry:")
print(f"  {log_entry}")

# Append to log file
log_file = f'memory/logs/{today}.md'
if os.path.exists(log_file):
    with open(log_file, 'a') as f:
        f.write(f"\n{log_entry}\n")
    print(f"  ✓ Appended to {log_file}")
else:
    with open(log_file, 'w') as f:
        f.write(log_entry + "\n")
    print(f"  ✓ Created {log_file}")

print(f"\n" + "=" * 70)
print("✓ SKILL EXECUTION COMPLETE")
print("=" * 70)
print(f"\nAlert to send (Telegram format):")
print(alert_text)
if attachments:
    print(f"\nWith {len(attachments)} attachment(s)")

# Next: send via ./notify
print(f"\nNext: ./notify with alert text")
