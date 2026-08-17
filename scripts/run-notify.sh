#!/usr/bin/env bash
MSG=$(cat .notify-msg.txt)
./notify "$MSG"
