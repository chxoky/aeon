#!/bin/bash
mkdir -p memory
echo "2081020096760422770" >> memory/x-trader-seen.txt
# Trim if over 5000 lines
LINES=$(wc -l < memory/x-trader-seen.txt 2>/dev/null || echo 0)
if [ "$LINES" -gt 5000 ]; then
  tail -2000 memory/x-trader-seen.txt > memory/x-trader-seen.tmp
  mv memory/x-trader-seen.tmp memory/x-trader-seen.txt
fi
echo "Updated seen list with 2081020096760422770"
