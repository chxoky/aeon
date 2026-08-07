#!/bin/bash
mkdir -p .media
cd .media
curl -sSL "https://pbs.twimg.com/media/HPHuOcjWgAAixZx.jpg" -o img_0.jpg
curl -sSL "https://pbs.twimg.com/media/HPHuOcNXQAA6sZ1.jpg" -o img_1.jpg
curl -sSL "https://pbs.twimg.com/media/HPC3k_2bcAAlly_K.jpg" -o img_2.jpg
ls -lh
