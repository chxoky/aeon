#!/bin/bash
mkdir -p .media
MEDIA_URL="https://pbs.twimg.com/media/HPnGtsqbUAAZKY_.jpg"
curl -sSL --max-time 20 "$MEDIA_URL" -o ".media/img_0.jpg" && echo "Downloaded" || echo "Failed"
