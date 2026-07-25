#!/bin/bash

TEXT="@stogolp Gay"

# Check if contains financial keywords
if echo "$TEXT" | grep -oE '\$[A-Z]' > /dev/null; then
  echo "Has ticker symbol"
  exit 1
fi

if echo "$TEXT" | grep -iE 'long|short|buy|sell|crypto|btc|eth|bitcoin|ethereum|trade|position|entry|target|level|support|resistance' > /dev/null; then
  echo "Has financial keywords"
  exit 1
fi

echo "Result: Non-financial content - will NOT send alert"
exit 0
