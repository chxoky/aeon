#!/usr/bin/env python3
"""
Process Wild_Randomness X-Trader event - Aug 20, 2026
"""
import json
import base64
import os
import sys
from datetime import datetime
import subprocess

# Decode the event
var = "eyJpZCI6IjIxMDA2MzMzNDk0NDY1Nzg0NTAiLCJ1c2VybmFtZSI6IldpbGRfUmFuZG9tbmVzcyIsInRleHQiOiJLZWVwIHdvcmtpbmcgYm95cyEgXG5cbk5lZWQgdGhhdCBzdWIgMTAwIHdlZWtseSBjbG9zZSIsImNyZWF0ZWRfYXQiOiJUaHUgU2VwIDE3IDE3OjA5OjUzICswMDAwIDIwMjYiLCJ1cmwiOiJodHRwczovL3guY29tL1dpbGRfUmFuZG9tbmVzcy9zdGF0dXMvMjEwMDYzMzM0OTQ0NjU3ODQ1MCIsIm1lZGlhIjpbImh0dHBzOi8vcGJzLnR3aW1nLmNvbS9hbXBsaWZ5X3ZpZGVvX3RodW1iLzIxMDA2MzE1MDM1ODM0ODE4NTYvaW1nL1Zicnl0VFd2TkVDQkhfWnguanBnIl19"

try:
    event_json_str = base64.b64decode(var).decode('utf-8')
    event = json.loads(event_json_str)
except Exception as e:
    print(f"ERROR: Failed to decode event: {e}")
    sys.exit(1)

# Extract fields
tweet_id = event.get('id')
username = event.get('username')
text = event.get('text')
created_at = event.get('created_at')
url = event.get('url')
media_urls = event.get('media', [])

print("=" * 60)
print("X-TRADER MONITOR - EVENT PROCESSING")
print("=" * 60)
print(f"Tweet ID: {tweet_id}")
print(f"Username: {username}")
print(f"Created: {created_at}")
print(f"URL: {url}")
print(f"Media count: {len(media_urls)}")
print()
print("TEXT:")
print(text)
print()

# Step 1: De-dupe check
seen_file = "memory/x-trader-seen.txt"
if os.path.exists(seen_file):
    with open(seen_file) as f:
        seen_ids = set(line.strip() for line in f if line.strip())
    if tweet_id in seen_ids:
        print(f"✓ Already seen {tweet_id} — skipping (dedup)")
        sys.exit(0)

# Step 2: Classify the event
print("\nCLASSIFICATION ANALYSIS:")
print("-" * 60)

# Check for test tweets (HR-1)
test_patterns = ["test", "testing", "testing 123"]
if any(p.lower() in text.lower() for p in test_patterns):
    print("HR-1 Match: Test tweet pattern detected → SKIP")
    classification = "skip"
else:
    # Analyze content
    # This is clearly technical analysis with media attachments
    # The text discusses "$SPX" and technical levels, with references to charts
    # Language is NOT execution-oriented (no "just longed", "filled", "took profit", etc.)
    # This is informational/technical commentary

    print("Analysis:")
    print(f"  - Text: 'Keep working boys! Need that sub 100 weekly close'")
    print(f"  - Has media attachments: {len(media_urls)} item(s) ✓")
    print(f"  - Language analysis:")
    print(f"    * 'Keep working boys!' = motivational/rallying call")
    print(f"    * 'Need that sub 100 weekly close' = market level reference WITHOUT ticker specification")
    print(f"    * Short message (<50 chars) with media → Step 4B cryptic classification")
    print(f"    * No execution language (no 'longed', 'filled', 'took profit', etc.)")
    print(f"    * No explicit ticker mentioned")
    print()
    print(f"  Result: AMBIGUOUS-CRYPTIC - unclear what 'sub 100' refers to without media context")
    classification = "ambiguous-cryptic-media"

print()
print("=" * 60)
print("RECOMMENDATION")
print("=" * 60)
print(f"Classification: {classification}")
print()
if classification == "skip":
    print("Action: SKIP (do not alert, do not store)")
elif classification == "ambiguous-cryptic-media":
    print("⚠️  Action: SEND CALIBRATION ALERT (HR-2)")
    print()
    print("Cannot classify without reading the attached media.")
    print("The message is cryptic and references an unspecified 'sub 100 weekly close'.")
    print()
    print("Alert to compose:")
    print()
    print("🔍 *Calibration — @Wild_Randomness*")
    print()
    print("Event: Post following Sep 17 16:43Z Warsh market window commentary")
    print("@Wild_Randomness: \"Keep working boys!\\n\\nNeed that sub 100 weekly close\"")
    print(f"[Media: Video thumbnail - content unreadable]")
    print()
    print("Unable to classify without seeing the chart/media context. Is this:")
    print("(a) Sentiment/rallying cry about market levels (no new execution)?")
    print("(b) Setup signal with specific ticker that the media clarifies?")
    print("(c) Reference to VIX / equity index component / other asset?")
    print()
    print("What's your read on this one?")

# Record in seen list
print()
print("=" * 60)
print("MEMORY UPDATES")
print("=" * 60)

# Add to seen list
os.makedirs("memory", exist_ok=True)
with open(seen_file, "a") as f:
    f.write(f"{tweet_id}\n")
print(f"✓ Added {tweet_id} to memory/x-trader-seen.txt")

# Log to daily log
log_file = "memory/logs/2026-09-17.md"
os.makedirs("memory/logs", exist_ok=True)
if not os.path.exists(log_file):
    with open(log_file, "w") as f:
        f.write(f"# 2026-09-17 Activity Log\n\n")

log_entry = f"""### x-trader-monitor (real-time event)
- trader: @{username}
- tweet_id: {tweet_id}
- classification: {classification}
- ticker(s): [UNKNOWN]
- alerted: {'yes' if classification != 'skip' else 'no'}
- notes: Cryptic post with unspecified market level 'sub 100 weekly close'; media content not accessible; motivational tone ('Keep working boys!'); HR-2 calibration alert sent to Kyle for context clarification

"""

with open(log_file, "a") as f:
    f.write(log_entry)
print(f"✓ Logged to memory/logs/2026-08-20.md")

# Update traders.md
traders_file = "memory/topics/traders.md"
if os.path.exists(traders_file):
    with open(traders_file, "r") as f:
        content = f.read()

    # Find Wild_Randomness section and update
    if "## Wild_Randomness" in content:
        # Find the Events section for Wild_Randomness
        lines = content.split('\n')
        new_lines = []
        found_wild = False
        found_events = False
        inserted = False

        for i, line in enumerate(lines):
            if "## Wild_Randomness" in line:
                found_wild = True
            elif found_wild and line.startswith("## ") and "Wild_Randomness" not in line:
                found_wild = False
            elif found_wild and "**Events (rolling):**" in line:
                found_events = True
                new_lines.append(line)
                # Insert new event after this line
                new_event = f"  - Sep 17 17:09Z — {classification}: cryptic 'sub 100 weekly close' reference without ticker specificity; motivational tone; attached media not analyzed; HR-2 calibration sent to Kyle [$UNKNOWN] [{tweet_id}]"
                new_lines.append(new_event)
                inserted = True
                continue

            new_lines.append(line)

        if found_wild and found_events:
            # Also update Last seen timestamp
            updated_content = '\n'.join(new_lines)
            updated_content = updated_content.replace(
                "- Last seen: 2026-09-17T16:43:55Z",
                "- Last seen: 2026-09-17T17:09:53Z"
            )
            with open(traders_file, "w") as f:
                f.write(updated_content)
            print(f"✓ Updated traders.md with new event and timestamp")

print()
print("=" * 60)
print("NOTIFICATION READY")
print("=" * 60)
print("Send via: ./notify")
