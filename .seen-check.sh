#!/usr/bin/env bash
set -euo pipefail
cd /home/runner/work/aeon/aeon
jq -r '.[].id' .xai-cache/trader-bootstrap-discord.json | sort -u > .cids.txt
sort -u memory/discord-trader-seen.txt > .sids.txt
echo "cache-unique=$(wc -l < .cids.txt)"
echo "already-seen=$(wc -l < .sids.txt)"
echo "new-not-seen=$(comm -23 .cids.txt .sids.txt | wc -l)"
# Idempotent mark-seen (Step 7)
jq -r '.[].id' .xai-cache/trader-bootstrap-discord.json >> memory/discord-trader-seen.txt
sort -u memory/discord-trader-seen.txt -o memory/discord-trader-seen.txt
echo "discord-seen-after=$(wc -l < memory/discord-trader-seen.txt)"
rm -f .cids.txt .sids.txt
