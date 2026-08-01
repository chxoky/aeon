#!/usr/bin/env bash
set -euo pipefail
MSG=$(cat notify_msg.txt)
./notify "$MSG"
