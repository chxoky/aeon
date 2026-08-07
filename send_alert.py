#!/usr/bin/env python3
import subprocess
import os

os.chdir('/home/runner/work/aeon/aeon')

msg = """🔍 *Calibration — [DC: HCH — Chat]*

Trader: heartcanhodl
Message: "Send them lower"

Unable to classify — is this a personal trade action or banter? What's your read?"""

result = subprocess.run(['./notify', msg], capture_output=True, text=True)
print(f"Alert sent. Return code: {result.returncode}")
if result.stderr:
    print(f"Stderr: {result.stderr}")
