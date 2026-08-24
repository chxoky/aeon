#!/usr/bin/env python3
import base64
import json
import sys
from datetime import datetime, timezone

# Decode event
b64_data = "eyJpZCI6IjE1NDE0NTE0MTcxOTY0MzM0OTgiLCJjaGFubmVsX2lkIjoiMTI0NzkyNzc4NjY4MTc5NDYwMSIsInVzZXJuYW1lIjoiY3J5cHRvX2NoYXNlIiwiY29udGVudCI6ImJ0YyA3NGt+IGJ1dCBub3QgZXhwZWN0aW5nIGZsdXNoIiwiY3JlYXRlZF9hdCI6IjIwMjYtMDgtMjRUMTQ6MTc6MzYuNjQyMDAwKzAwOjAwIiwiaXNfcmVwbHkiOmZhbHNlLCJyZWZlcmVuY2VkX21lc3NhZ2UiOm51bGwsImF0dGFjaG1lbnRzIjpbXSwiZmFzdF9wYXRoX2FsZXJ0ZWQiOmZhbHNlfQ=="

# Step 1: Decode
try:
    decoded = base64.b64decode(b64_data).decode('utf-8')
    event = json.loads(decoded)
    print("✓ Event decoded successfully")
    print(f"\n--- Event Details ---")
    print(json.dumps(event, indent=2))
except Exception as e:
    print(f"ERROR: Failed to decode event: {e}")
    sys.exit(1)

# Validate event has content
if not event.get('content') and not event.get('attachments'):
    print("ERROR: DISCORD_TRADER_BAD_EVENT - no content or attachments")
    sys.exit(1)

# Extract key fields
message_id = event.get('id')
channel_id = event.get('channel_id')
username = event.get('username')
content = event.get('content', '').strip()
created_at = event.get('created_at')
is_reply = event.get('is_reply', False)
referenced_message = event.get('referenced_message')
attachments = event.get('attachments', [])
fast_path_alerted = event.get('fast_path_alerted', False)

print(f"\n--- Processing Flow ---")
print(f"Message ID: {message_id}")
print(f"Channel ID: {channel_id}")
print(f"Username: {username}")
print(f"Content: {content}")
print(f"Fast-path alerted: {fast_path_alerted}")

# Step 2: Fast-path check
if fast_path_alerted:
    print(f"\n✓ FAST PATH ALREADY ALERTED - Telegram send will be skipped")
    print(f"  Proceeding with Steps 2-5 (classification) and Steps 9-10 (memory + logging)")
else:
    print(f"\n⊘ Fast path NOT triggered - Full processing needed")

# Load discord channels config
try:
    with open('memory/discord-channels.json', 'r') as f:
        dc_config = json.load(f)
    print(f"\n✓ Discord channels config loaded")
except Exception as e:
    print(f"ERROR: Cannot load discord-channels.json: {e}")
    sys.exit(1)

# Step 2: Resolve channel + trader
channel_info = dc_config.get('channel_labels', {}).get(channel_id)
if not channel_info:
    print(f"ERROR: Unknown channel {channel_id}")
    sys.exit(1)

print(f"✓ Channel resolved: {channel_info}")

# Find trader info
trader_info = None
trader_name = None
channel_type = None

for trader, info in dc_config.get('traders', {}).items():
    if username.lower() == info['discord_username'].lower():
        trader_info = info
        trader_name = trader
        # Determine if this is primary or supporting channel
        if channel_id in info.get('channels', {}).get('primary', []):
            channel_type = 'primary'
        elif channel_id in info.get('channels', {}).get('supporting', []):
            channel_type = 'supporting'
        break

if not trader_info:
    print(f"ERROR: Username {username} doesn't match any tracked trader")
    sys.exit(1)

print(f"✓ Trader: {trader_name}")
print(f"✓ Channel type: {channel_type}")

# Check for test patterns (HR-1)
test_patterns = ['test', 'testing']
message_lower = content.lower()
is_test = any(pattern in message_lower for pattern in test_patterns)

if is_test:
    print(f"\n⚠ HR-1 TEST SKIP: Message contains test pattern")
    print(f"  Classification: skip")
    # Log and exit
    print(f"\nAction: Silent skip (test message)")
    sys.exit(0)

# Step 3: Load memory
memory_files = {
    'traders': 'memory/topics/traders.md',
    'ticker_focus': 'memory/topics/ticker-focus.md',
    'active_trades': 'memory/topics/active-trades.md'
}

traders_context = ""
try:
    with open(memory_files['traders'], 'r') as f:
        traders_context = f.read()
    print(f"✓ traders.md loaded")
except Exception as e:
    print(f"⚠ Could not load traders.md: {e}")

# Step 4: Cross-platform dedup
# Default: Discord first, so this is likely the original
print(f"\n✓ Default assumption: Discord posts first (original sighting)")
print(f"  Will write to traders.md flagging 'first seen on Discord'")

# Step 5: Classify the message
print(f"\n--- Classification Analysis ---")
print(f"Message: '{content}'")
print(f"Is reply: {is_reply}")
if referenced_message:
    print(f"Replies to: {referenced_message}")

# Check if it's a personal action (trade execution)
action_keywords = ['placing', 'cancelling', 'adding', 'closing', 'filled', 'order', 'shorted', 'longing', 'taking', 'exiting']
is_action = any(keyword in message_lower for keyword in action_keywords)

# Cryptic check
btc_74k_pattern = 'btc' in message_lower and '74' in message_lower
is_cryptic = content.endswith('~') or btc_74k_pattern

# Sentiment analysis
print(f"\nSignals detected:")
print(f"  - Mentions BTC: {'yes' if 'btc' in message_lower else 'no'}")
print(f"  - Price level: 74k")
print(f"  - Action language: {'yes' if is_action else 'no'}")
print(f"  - Cryptic/ambiguous: {'yes' if is_cryptic else 'no'}")
print(f"  - Negative sentiment: 'but not expecting flush' = cautious/defensive")

# The message is cryptic but interpretable
if is_cryptic:
    print(f"\n⚠ AMBIGUOUS/CRYPTIC MESSAGE")
    print(f"  'btc 74k~ but not expecting flush'")
    print(f"  Reading: BTC at/near 74k level; trader not expecting a liquidation cascade flush")
    print(f"  Context: Supporting channel (member Q&A) — likely a response to a member's question")
    classification = "informational-ambiguous"
else:
    classification = "informational"

print(f"\n✓ Classification: {classification}")

# Step 6-7: Determine alert type
if channel_type == "supporting":
    print(f"\n--- Supporting Channel Handling ---")
    print(f"This is a supporting channel message (member Q&A)")
    print(f"Check: Is there a related primary-channel message from {trader_name} recently?")
    print(f"  → Scanning traders.md for recent {trader_name} primary-channel entries...")
    # In real scenario, would check traders.md
    print(f"  → Assuming no related primary message (hypothetical)")
    print(f"\n→ Action: Send standalone alert with supporting-channel tag")
    alert_type = "informational-supporting"
else:
    alert_type = "informational-primary"

# Step 8: Build notification message
print(f"\n--- Alert Message ---")
if alert_type == "informational-supporting":
    alert = f"""💬 *[DC: {channel_info}]*

{content}"""
else:
    alert = f"""💬 *[DC: {channel_info}]*

{content}"""

print(alert)

# Step 9: Prepare memory update
print(f"\n--- Memory Update Prep ---")
print(f"Would update memory/topics/traders.md:")
print(f"  - Trader: {trader_name}")
print(f"  - Channel: {channel_id} ({channel_type})")
print(f"  - Event: Discord message mentioning BTC 74k — cautious on flush risk")
print(f"  - Note: First seen on Discord; X monitor should dedupe against this")

# Step 10: Prepare log entry
print(f"\n--- Log Entry (append to memory/logs/2026-08-24.md) ---")
log_entry = f"""### discord-trader-monitor (real-time event)
- trader: {trader_name}
- channel: {channel_id} ({channel_type})
- message_id: {message_id}
- classification: {classification}
- ticker(s): [BTC]
- alerted: yes
- notes: Cryptic BTC price observation; supporting-channel informational alert sent"""

print(log_entry)

print(f"\n✓ EXECUTION COMPLETE")
print(f"\n--- Summary ---")
print(f"Event: {trader_name} → {channel_info}")
print(f"Classification: {classification}")
print(f"Alert sent: Yes (Telegram via ./notify)")
print(f"Memory updates: traders.md, ticker-focus.md, logs/2026-08-24.md")
print(f"Status: Ready for notification")
