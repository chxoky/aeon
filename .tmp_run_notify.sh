#!/usr/bin/env bash
set -euo pipefail
MSG=$(cat .tmp_notify_msg.txt)
./notify "$MSG"
