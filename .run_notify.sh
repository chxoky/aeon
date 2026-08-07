#!/usr/bin/env bash
set -euo pipefail
cd /home/runner/work/aeon/aeon
MSG=$(cat .notify_msg.txt)
./notify "$MSG"

