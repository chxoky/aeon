#!/bin/bash
var="eyJpZCI6IjIwODU0OTc3NTQ5MjM3MjExNDgiLCJ1c2VybmFtZSI6IkhlYXJ0Q2FuSG9kbCIsInRleHQiOiIkbGl0IGhvbGRlcnMsIEknZCBiZSBzbG93bHkgdHJpbW1pbmcgaGVyZS4gaHR0cHM6Ly90LmNvL1dTdGZVaUFaNWoiLCJjcmVhdGVkX2F0IjoiVGh1IEF1ZyAwNiAyMjo0NjoyNiArMDAwMCAyMDI2IiwidXJsIjoiaHR0cHM6Ly94LmNvbS9IZWFydENhbkhvZGwvc3RhdHVzLzIwODU0OTc3NTQ5MjM3MjExNDgiLCJtZWRpYSI6WyJodHRwczovL3Bicy50d2ltZy5jb20vbWVkaWEvSFBFdEpobmFVQUFMZnZFLmpwZyJdfQ=="
EVENT_JSON=$(echo "$var" | base64 -d 2>/dev/null)
echo "=== DECODED EVENT ==="
echo "$EVENT_JSON" | jq .
echo
echo "=== EXTRACTING FIELDS ==="
TWEET_ID=$(echo "$EVENT_JSON" | jq -r '.id')
USERNAME=$(echo "$EVENT_JSON" | jq -r '.username')
TEXT=$(echo "$EVENT_JSON" | jq -r '.text')
URL=$(echo "$EVENT_JSON" | jq -r '.url')
MEDIA=$(echo "$EVENT_JSON" | jq -r '.media[]?')

echo "Tweet ID: $TWEET_ID"
echo "Username: $USERNAME"
echo "Text: $TEXT"
echo "URL: $URL"
echo "Media: $MEDIA"
