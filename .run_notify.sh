#!/usr/bin/env bash
set -euo pipefail
MSG=$(cat /home/runner/work/aeon/aeon/.notify_msg.txt)
/home/runner/work/aeon/aeon/notify "$MSG"
