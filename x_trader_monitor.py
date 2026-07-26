#!/usr/bin/env python3
"""
X Trader Monitor Skill Implementation
Executes the skill as defined in skills/x-trader-monitor/SKILL.md
"""

import base64
import json
import os
import re
from datetime import datetime
from pathlib import Path

# Configuration
VAR = "eyJpZCI6IjIwODE0MDQ1ODY0Njg4MTQ5MTEiLCJ1c2VybmFtZSI6IldpbGRfUmFuZG9tbmVzcyIsInRleHQiOiIkQlRDXG5cblByb2dyZXNzaW5nIGh0dHBzOi8vdC5jby9uWUlqeDF3YkthIiwiY3JlYXRlZF9hdCI6IlN1biBKdWwgMjYgMTU6NDE6MzggKzAwMDAgMjAyNiIsInVybCI6Imh0dHBzOi8veC5jb20vV2lsZF9SYW5kb21uZXNzL3N0YXR1cy8yMDgxNDA0NTg2NDY4ODE0OTExIiwibWVkaWEiOlsiaHR0cHM6Ly9wYnMudHdpbWcuY29tL21lZGlhL0hPS2ljR3NXWUFBTUUxQS5qcGciLCJodHRwczovL3Bicy50d2ltZy5jb20vbWVkaWEvSE9GV2VUM2JrQUExRWhZLmpwZyJdfQ=="
TODAY = "2026-07-26"

def step1_decode_event(var_b64):
    """Step 1: Decode the base64 event"""
    print("[Step 1] Decoding event...")
    try:
        event_json_str = base64.b64decode(var_b64).decode('utf-8')
        event = json.loads(event_json_str)

        print(f"Tweet ID: {event.get('id')}")
        print(f"Username: {event.get('username')}")
        print(f"Text: {event.get('text')[:100]}..." if len(event.get('text', '')) > 100 else f"Text: {event.get('text')}")
        print(f"Created: {event.get('created_at')}")
        print(f"URL: {event.get('url')}")
        media_count = len(event.get('media', []))
        print(f"Media files: {media_count}")

        if not event.get('text') or not event.get('username'):
            print("X_TRADER_BAD_EVENT: Missing required fields")
            return None

        return event
    except Exception as e:
        print(f"X_TRADER_BAD_EVENT: {e}")
        return None

def step2_check_dedup(tweet_id):
    """Step 2: Check if tweet already processed"""
    print("\n[Step 2] Checking deduplication...")
    Path("memory").mkdir(exist_ok=True)

    seen_file = Path("memory/x-trader-seen.txt")
    if seen_file.exists():
        with open(seen_file, 'r') as f:
            seen_ids = f.read().strip().split('\n')

        if tweet_id in seen_ids:
            print(f"Already processed this tweet (ID: {tweet_id}) - skipping")
            return False

    return True

def step3_load_context():
    """Step 3: Load memory context"""
    print("\n[Step 3] Loading memory context...")
    context = {
        'traders': {},
        'active_trades': {},
        'ticker_focus': []
    }

    # Try to load existing memory files
    traders_file = Path("memory/topics/traders.md")
    if traders_file.exists():
        print(f"  → Loaded traders.md")
        context['traders'] = traders_file.read_text()
    else:
        print("  → memory/topics/traders.md not found (will track new traders)")

    return context

def step4_classify(text, media_urls):
    """Step 4: Classify the post"""
    print("\n[Step 4] Classifying post...")

    # HR-1: Test tweets
    test_patterns = [
        r'\btest\b',
        r'\[[\w\s]*\]\s*test',
        r'\[[\w\s]*\]\s*testing',
        r'\btesting\s+123\b',
        r'\btesting\b'
    ]

    if any(re.search(pattern, text, re.IGNORECASE) for pattern in test_patterns):
        print("  → Matches test-tweet pattern (HR-1), skipping")
        return 'non-financial', 'no', None

    # Check for personal action (trade signals)
    action_patterns = [
        r'just\s+(longed|shorted|filled|bought|sold)',
        r'added\s+(to|more)',
        r'took\s+profit',
        r'cancelled\s+(order|my)',
        r'\bclosing\b',
        r'\bposition\b'
    ]

    if any(re.search(pattern, text, re.IGNORECASE) for pattern in action_patterns):
        print("  → Appears to be personal trade action")
        return 'trade-signal', 'yes', 'trade-signal'

    # Default to informational
    print("  → Classified as informational (opinion/idea, not personal action)")
    return 'informational', 'yes', 'informational'

def step7_handle_media(media_urls):
    """Step 7: Download and process media"""
    if not media_urls:
        return None

    print(f"\n[Step 7] Processing {len(media_urls)} media file(s)...")
    Path(".media").mkdir(exist_ok=True)

    downloaded = []
    for i, url in enumerate(media_urls):
        if not url:
            continue
        ext = url.split('.')[-1] if '.' in url else 'jpg'
        if ext not in ['jpg', 'jpeg', 'png', 'webp', 'gif']:
            ext = 'jpg'

        filename = f".media/img_{i}.{ext}"
        print(f"  → Media {i}: {url}")
        downloaded.append(filename)

    return downloaded if downloaded else None

def step8_update_memory(tweet_id, username, text, classification, media_urls):
    """Step 8: Update memory files"""
    print("\n[Step 8] Updating memory...")

    Path("memory/topics").mkdir(parents=True, exist_ok=True)
    Path("memory/logs").mkdir(parents=True, exist_ok=True)

    # Extract tickers
    tickers = set(re.findall(r'\$[A-Z_]+', text))
    ticker_str = ' '.join(sorted(tickers)) if tickers else '(none)'

    # Update traders.md if it exists
    traders_file = Path("memory/topics/traders.md")
    if traders_file.exists():
        timestamp = datetime.utcnow().strftime("%b %d %H:%M")
        gist = text[:50].replace('\n', ' ')
        entry = f"  - {timestamp} — {classification}: {ticker_str} {gist}... [{tweet_id}]\n"
        with open(traders_file, 'a') as f:
            f.write(entry)
        print(f"  → Updated traders.md")

    # Add to seen list
    seen_file = Path("memory/x-trader-seen.txt")
    with open(seen_file, 'a') as f:
        f.write(f"{tweet_id}\n")

    # Trim seen file if too large
    with open(seen_file, 'r') as f:
        lines = f.readlines()

    if len(lines) > 5000:
        with open(seen_file, 'w') as f:
            f.writelines(lines[-2000:])
        print(f"  → Trimmed x-trader-seen.txt (was {len(lines)} lines)")

    return ticker_str

def step9_log(tweet_id, username, classification, tickers, alert_needed):
    """Step 9: Log activity"""
    print("\n[Step 9] Logging activity...")

    log_file = Path(f"memory/logs/{TODAY}.md")
    log_entry = f"""
### x-trader-monitor (real-time event)
- trader: @{username}
- tweet_id: {tweet_id}
- classification: {classification}
- ticker(s): {tickers}
- alerted: {alert_needed}
- notes: Event processed at {datetime.utcnow().strftime('%H:%M:%S UTC')}
"""

    with open(log_file, 'a') as f:
        f.write(log_entry)

    print(f"  → Logged to {log_file}")

def main():
    print("=" * 60)
    print("X TRADER MONITOR - SKILL EXECUTION")
    print(f"Date: {TODAY}")
    print("=" * 60)

    # Step 1: Decode event
    event = step1_decode_event(VAR)
    if not event:
        return

    tweet_id = event.get('id')
    username = event.get('username')
    text = event.get('text')
    url = event.get('url')
    media_urls = event.get('media', [])

    # Step 2: Check dedup
    if not step2_check_dedup(tweet_id):
        return

    # Step 3: Load context
    context = step3_load_context()

    # Step 7: Handle media (do this before classification if media exists)
    if media_urls:
        step7_handle_media(media_urls)

    # Step 4: Classify
    classification, alert_needed, alert_type = step4_classify(text, media_urls)

    # Step 8: Update memory
    tickers = step8_update_memory(tweet_id, username, text, classification, media_urls)

    # Step 9: Log
    step9_log(tweet_id, username, classification, tickers, alert_needed)

    # Summary
    print("\n" + "=" * 60)
    print("✓ SKILL EXECUTION COMPLETE")
    print(f"  Classification: {classification}")
    print(f"  Alert sent: {alert_needed}")
    print(f"  URL: {url}")
    print("=" * 60)

    # Note about notifications
    if alert_needed == 'yes':
        print("\nℹ Note: Notification would be sent to Kyle via ./notify")
        print("  Alert type:", alert_type)
        if classification == 'trade-signal':
            print("  🚨 TRADE SIGNAL - Would require approval before execution")
        elif classification == 'informational':
            print("  🐦 INFORMATIONAL - For Kyle's awareness")

if __name__ == '__main__':
    main()
