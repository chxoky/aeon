#!/bin/bash
mkdir -p .media
cd .media

curl -sSL --max-time 20 "https://pbs.twimg.com/media/HSe9cFMXwAA5Ub8.jpg" -o "img_0.jpg" && echo "✓ img_0.jpg" || echo "✗ img_0.jpg"
curl -sSL --max-time 20 "https://pbs.twimg.com/media/HSe9dApXMAIhHk.jpg" -o "img_1.jpg" && echo "✓ img_1.jpg" || echo "✗ img_1.jpg"

ls -lh *.jpg
