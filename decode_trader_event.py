#!/usr/bin/env python3

import base64
import json
import sys
import os
from datetime import datetime

# The event variable
var = "eyJpZCI6IjIwODEwMjAwOTY3NjA0MjI3NzAiLCJ1c2VybmFtZSI6IldpbGRfUmFuZG9tbmVzcyIsInRleHQiOiJodHRwczovL3QuY28vSWRVeVg4aURMWiIsImNyZWF0ZWRfYXQiOiJTYXQgSnVsIDI1IDE0OjEzOjQ5ICswMDAwIDIwMjYiLCJ1cmwiOiJodHRwczovL3guY29tL1dpbGRfUmFuZG9tbmVzcy9zdGF0dXMvMjA4MTAyMDA5Njc2MDQyMjc3MCIsIm1lZGlhIjpbImh0dHBzOi8vcGJzLnR3aW1nLmNvbS9tZWRpYS9IT0ZFdmZfYVlBQUp4M0MuanBnIiwiaHR0cHM6Ly9wYnMudHdpbWcuY29tL21lZGlhL0hPRkV2Z0dhSUFBeXIzai5qcGciXX0="

# Step 1: Decode
try:
    event_json = base64.b64decode(var).decode('utf-8')
    event = json.loads(event_json)
except Exception as e:
    print(f"X_TRADER_BAD_EVENT: {e}")
    sys.exit(1)

# Extract fields
tweet_id = event.get('id')
username = event.get('username')
text = event.get('text')
created_at = event.get('created_at')
url = event.get('url')
media = event.get('media', [])

print("=== DECODED EVENT ===")
print(f"Tweet ID: {tweet_id}")
print(f"Username: @{username}")
print(f"Text: {text}")
print(f"Created: {created_at}")
print(f"URL: {url}")
print(f"Media: {media}")
print()

# Check if already seen
seen_file = "memory/x-trader-seen.txt"
if os.path.exists(seen_file):
    with open(seen_file, 'r') as f:
        seen_ids = f.read().strip().split('\n')
    if tweet_id in seen_ids:
        print("=== DUPLICATE ===")
        print(f"Tweet ID {tweet_id} already processed")
        sys.exit(0)

# Add to seen list
os.makedirs("memory", exist_ok=True)
with open(seen_file, 'a') as f:
    f.write(f"{tweet_id}\n")

# Trim if needed
with open(seen_file, 'r') as f:
    lines = f.readlines()
if len(lines) > 5000:
    with open(seen_file, 'w') as f:
        f.writelines(lines[-2000:])

print("=== EVENT PROCESSED ===")
print(f"Added tweet {tweet_id} to seen list")

# Save full event for processing
with open(".trader-event.json", 'w') as f:
    json.dump(event, f)
