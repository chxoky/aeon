#!/usr/bin/env bash
set -euo pipefail
MSG=$(cat .notify-narrative.txt)
exec ./notify "$MSG"
