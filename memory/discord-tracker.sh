#!/bin/bash
mkdir -p /home/runner/work/aeon/aeon/memory
echo "1534130818669084672" >> /home/runner/work/aeon/aeon/memory/discord-trader-seen.txt

# Prune if over 5000 lines
LINE_COUNT=$(wc -l < /home/runner/work/aeon/aeon/memory/discord-trader-seen.txt)
if [ "$LINE_COUNT" -gt "5000" ]; then
  tail -2000 /home/runner/work/aeon/aeon/memory/discord-trader-seen.txt > /tmp/discord-seen-temp.txt
  mv /tmp/discord-seen-temp.txt /home/runner/work/aeon/aeon/memory/discord-trader-seen.txt
fi

echo "Message tracked."
