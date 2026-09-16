#!/bin/bash
cd /home/runner/work/aeon/aeon

# Send calibration alert for Stoiiic cryptic tweet
./notify "🔍 *Calibration — @Stoiiic*

Event: Reply in conversation with @Gigaintern69
@Stoiiic: \"@Gigaintern69 LOW\"

Unable to classify — what's your read? Is this a bearish sentiment, price target, or something else?

[View post](https://x.com/Stoiiic/status/2100254364162039842)"

echo "✓ Calibration alert sent"
