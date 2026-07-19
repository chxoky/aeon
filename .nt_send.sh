#!/usr/bin/env bash
set -euo pipefail
MSG="$(cat /tmp/nt_msg.txt)"
./notify "$MSG"
