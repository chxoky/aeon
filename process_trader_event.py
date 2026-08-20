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
var = "eyJpZCI6IjIwOTA1NDQyNTI2NDAyMzU4ODIiLCJ1c2VybmFtZSI6IldpbGRfUmFuZG9tbmVzcyIsInRleHQiOiIkU1BYXG5cbipJRiogd2UgZ2V0IGEgcmVwZWF0IG9mIHRvZGF54oCZcyBhY3Rpb24gdG9tb3Jyb3csIHRoaXMgY2hhcnQgaXMgc28gY29va2VkIGJleW9uZCB3b3Jkc1xuXG5Ob2JvZHkgaXMgZ29pbmcgdG8gaGFuZCBhcm91bmQgZm9yIG11aCBBbnRocm9waWMgSVBPIGlmIHRoaXMgZGV2aWF0aW9uIGxvY2tzIGlu4oCmXG5cbihJ4oCZdmUgYWxyZWFkeSBoaWdobGlnaHRlZCB0aGF0IHRoaXMgZGV2aWF0aW9uIGlzIGxpa2VseSB0byBsb2NrIGluIG9uIGEgY3VycmVuY3ktYWRqdXN0ZWQgYmFzaXMpIGh0dHBzOi8vdC5jby9wdk95N2J6UVdGIiwiY3JlYXRlZF9hdCI6IlRodSBBdWcgMjAgMjA6NTk6MjQgKzAwMDAgMjAyNiIsInVybCI6Imh0dHBzOi8veC5jb20vV2lsZF9SYW5kb21uZXNzL3N0YXR1cy8yMDkwNTQ0MjUyNjQwMjM1ODgyIiwibWVkaWEiOlsiaHR0cHM6Ly9wYnMudHdpbWcuY29tL21lZGlhL0hRTWE2dTNiRUFBempnSy5qcGciLCJodHRwczovL3Bicy50d2ltZy5jb20vbWVkaWEvSFFNYTZ1NGFFQUFOU3QtLmpwZyIsImh0dHBzOi8vcGJzLnR3aW1nLmNvbS9tZWRpYS9IUUdTeG4zYkVBUWlZRVEuanBnIl19"

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
    print(f"  - Contains ticker: $SPX ✓")
    print(f"  - Has media attachments: {len(media_urls)} charts ✓")
    print(f"  - Language analysis:")
    print(f"    * 'IF we get a repeat' = conditional/hypothetical")
    print(f"    * 'this chart is so cooked' = technical analysis commentary")
    print(f"    * 'Nobody is going to hand around' = market sentiment observation")
    print(f"    * No execution language (no 'longed', 'filled', 'took profit', etc.)")
    print()
    print(f"  Result: INFORMATIONAL - technical analysis + price level discussion")
    classification = "informational-technical"

print()
print("=" * 60)
print("RECOMMENDATION")
print("=" * 60)
print(f"Classification: {classification}")
print()
if classification == "skip":
    print("Action: SKIP (do not alert, do not store)")
elif classification == "informational-technical":
    print("Action: SEND INFORMATIONAL ALERT")
    print()
    print("Alert to compose:")
    print()
    print("🐦 *[X] @Wild_Randomness*")
    print()
    print("$SPX")
    print()
    print("*IF* we get a repeat of today's action tomorrow, this chart is so cooked beyond words")
    print()
    print("Nobody is going to hand around for muh Anthropic IPO if this deviation locks in…")
    print()
    print("(I've already highlighted that this deviation is likely to lock in on a currency-adjusted basis)")
    print()
    print(f"[View tweet]({url})")
    print()
    print("Cross-reference: Wild_Randomness has been tracking SPX technical structure and macro equity dispersion")

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
log_file = "memory/logs/2026-08-20.md"
os.makedirs("memory/logs", exist_ok=True)
if not os.path.exists(log_file):
    with open(log_file, "w") as f:
        f.write(f"# 2026-08-20 Activity Log\n\n")

log_entry = f"""### x-trader-monitor (real-time event)
- trader: @{username}
- tweet_id: {tweet_id}
- classification: {classification}
- ticker(s): [SPX]
- alerted: {'yes' if classification != 'skip' else 'no'}
- notes: Technical analysis on SPX structure and macro deviation patterns; 3 chart attachments provided; conditional market outlook commentary; references Anthropic IPO sentiment impact

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
                new_event = f"  - Aug 20 20:59Z — {classification}: SPX technical structure + macro deviation patterns; conditional price-action replication concern; charts showing equity indices structure; Anthropic IPO sentiment dependency noted; no personal execution language; alerted Kyle [$SPX] [{tweet_id}]"
                new_lines.append(new_event)
                inserted = True
                continue

            new_lines.append(line)

        if found_wild and found_events:
            # Also update Last seen timestamp
            updated_content = '\n'.join(new_lines)
            updated_content = updated_content.replace(
                "- Last seen: 2026-08-20T20:49:01Z",
                "- Last seen: 2026-08-20T20:59:24Z"
            )
            with open(traders_file, "w") as f:
                f.write(updated_content)
            print(f"✓ Updated traders.md with new event and timestamp")

print()
print("=" * 60)
print("NOTIFICATION READY")
print("=" * 60)
print("Send via: ./notify")
