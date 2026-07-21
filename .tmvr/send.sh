#!/usr/bin/env bash
set -euo pipefail
cd /home/runner/work/aeon/aeon
MSG="$(cat .tmvr/msg.txt)"
./notify "$MSG"
