#!/usr/bin/env bash
# One-off helper for trader-bootstrap Step 7: mark all fetched IDs as seen.
set -euo pipefail
mkdir -p memory
jq -r '.[].id' .xai-cache/trader-bootstrap-x.json >> memory/x-trader-seen.txt
jq -r '.[].id' .xai-cache/trader-bootstrap-discord.json >> memory/discord-trader-seen.txt
sort -u memory/x-trader-seen.txt -o memory/x-trader-seen.txt
sort -u memory/discord-trader-seen.txt -o memory/discord-trader-seen.txt
wc -l memory/x-trader-seen.txt memory/discord-trader-seen.txt
