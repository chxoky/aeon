#!/bin/bash
mkdir -p /home/runner/work/aeon/aeon/.media
cd /home/runner/work/aeon/aeon/.media

urls=(
  "https://pbs.twimg.com/media/HPizaYbbgAA54my.jpg"
  "https://pbs.twimg.com/media/HPizaYbwAAQamF.jpg"
  "https://pbs.twimg.com/media/HPXogA0aUAAcv8f.jpg"
  "https://pbs.twimg.com/media/HPXogA0bEAAJryp.jpg"
)

i=1
for u in "${urls[@]}"; do
  curl -sL "$u" -o "img_$i.jpg" --max-time 20
  if [ $? -eq 0 ]; then
    echo "Saved img_$i.jpg"
  else
    echo "Failed: $u"
  fi
  i=$((i+1))
done

ls -lh
