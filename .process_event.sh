#!/bin/bash
set -e

# Decode the base64 event
var="eyJpZCI6IjIwOTEwMDgxMDg2ODQyNjM3NDciLCJ1c2VybmFtZSI6InRyYWRpbmdfYXhlIiwidGV4dCI6IktyYWtlbiDwn6Sd8J+HuvCfh7ggIFlZUFMg8J+TiPCfpK9cblxuQ3J5cHRvZG90Y29tIPCfpJ3wn4e68J+HuCAhIExJVCDwn5Sc8J+TiPCfpK9cblxufiBEci4gQXhpdXMuIiwiY3JlYXRlZF9hdCI6IlNhdCBBdWcgMjIgMDM6NDI6MzYgKzAwMDAgMjAyNiIsInVybCI6Imh0dHBzOi8veC5jb20vdHJhZGluZ19heGUvc3RhdHVzLzIwOTEwMDgxMDg2ODQyNjM3NDciLCJtZWRpYSI6W119"

EVENT_JSON=$(echo "$var" | base64 -d 2>/dev/null)

if [ -z "$EVENT_JSON" ]; then
  echo "X_TRADER_BAD_EVENT"
  exit 1
fi

echo "$EVENT_JSON" | jq .
