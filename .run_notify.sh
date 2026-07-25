#!/usr/bin/env bash
cd /home/runner/work/aeon/aeon
MSG=$(cat .token_movers_msg.txt)
./notify "$MSG"

