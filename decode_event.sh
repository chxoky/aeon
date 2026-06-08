#!/bin/bash

var='eyJpZCI6IjIwNjQwODA5NzI3OTEwMzc5OTIiLCJ1c2VybmFtZSI6InVua25vd24iLCJ0ZXh0IjoiUmVtYXJrYWJseSwgYm90aCBvY2N1cnJlbmNlcyBsaW5lZCB1cCBhbG1vc3QgcGVyZmVjdGx5IHdpdGggYSBsb2NhbCB0b3AgaHR0cHM6Ly90LmNvLzRXYnR6MERnZlAiLCJjcmVhdGVkX2F0IjoiIiwidXJsIjoiaHR0cHM6Ly94LmNvbS91bmtub3duL3N0YXR1cy8yMDY0MDgwOTcyNzkxMDM3OTkyIiwibWVkaWEiOltdfQ=='

EVENT_JSON=$(echo "$var" | base64 -d 2>/dev/null)

if [ -z "$EVENT_JSON" ]; then
    echo "X_TRADER_BAD_EVENT: Failed to decode"
    exit 1
fi

echo "$EVENT_JSON" | jq .
