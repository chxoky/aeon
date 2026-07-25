#!/bin/bash
mkdir -p .media
curl -sSL --max-time 20 "https://pbs.twimg.com/media/HOFEvf_aYAQJx3C.jpg" -o ".media/img_0.jpg"
curl -sSL --max-time 20 "https://pbs.twimg.com/media/HOFEvgGaIAAyr3j.jpg" -o ".media/img_1.jpg"
ls -lh .media/img_*
