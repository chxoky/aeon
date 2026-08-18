#!/usr/bin/env bash
MSG=$(cat notify-message.txt)
./notify "$MSG"
