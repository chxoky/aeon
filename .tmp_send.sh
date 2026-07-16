#!/usr/bin/env bash
set -euo pipefail
MSG="$(cat .tmp_msg.md)"
./notify "$MSG"
