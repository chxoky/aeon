#!/bin/bash
cd /home/runner/work/aeon/aeon
MESSAGE=$(cat hch-calibration-alert.txt)
./notify "$MESSAGE"
echo "Calibration alert sent"
