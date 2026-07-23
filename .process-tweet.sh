#!/bin/bash

# Add tweet ID to dedup list
echo "2080186478819164616" >> memory/x-trader-seen.txt

# Trim if needed
line_count=$(wc -l < memory/x-trader-seen.txt)
if [ $line_count -gt 5000 ]; then
  tail -2000 memory/x-trader-seen.txt > memory/x-trader-seen.tmp
  mv memory/x-trader-seen.tmp memory/x-trader-seen.txt
fi

echo "Dedup list updated"
