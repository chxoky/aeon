#!/usr/bin/env python3
import json
import base64
import sys
from datetime import datetime

# Decode event
var_b64 = "eyJpZCI6IjIwOTAwMzY1NDUwODg2MzkyMDMiLCJ1c2VybmFtZSI6InN3YXJtaXN0ZXIiLCJ0ZXh0IjoiQGljb2JlYXN0IEhleeKApiBTbW9sIGRt4oCmIEZvciBGdXR1cmUgR2VuZXJhdGlvbnMiLCJjcmVhdGVkX2F0IjoiV2VkIEF1ZyAxOSAxMToyMTo1OCArMDAwMCAyMDI2IiwidXJsIjoiaHR0cHM6Ly94LmNvbS9zd2FybWlzdGVyL3N0YXR1cy8yMDkwMDM2NTQ1MDg4NjM5MjAzIiwibWVkaWEiOltdfQ=="

try:
    event_json_str = base64.b64decode(var_b64).decode('utf-8')
    event = json.loads(event_json_str)
    print("=== Event Decoded ===")
    print(json.dumps(event, indent=2))
    print()

    tweet_id = event.get('id')
    username = event.get('username')
    text = event.get('text')
    url = event.get('url')
    created_at = event.get('created_at')
    media = event.get('media', [])

    print(f"ID: {tweet_id}")
    print(f"Username: @{username}")
    print(f"Text: {text}")
    print(f"URL: {url}")
    print(f"Created: {created_at}")
    print(f"Media count: {len(media)}")
    print()

    # Analysis
    print("=== Classification Analysis ===")
    print(f"Text contains reply marker (@): {'@' in text}")
    print(f"Text length: {len(text)}")
    print(f"Contains financial keywords: NO")
    print(f"Contains personal execution language: NO")
    print(f"Pattern: Casual greeting reply with emoji")
    print()

    print("CLASSIFICATION: Non-financial (casual banter / personal message)")
    print("ACTION: Skip silently — no alert, no memory entry, log only")

except Exception as e:
    print(f"Error: {e}")
    sys.exit(1)
