#!/bin/bash
mkdir -p .media
urls=(
  "https://pbs.twimg.com/media/HO0p-AlbkAAhbFn.jpg"
  "https://pbs.twimg.com/media/HO0bm5HaYAAxGTx.jpg"
)

i=0
for u in "${urls[@]}"; do
  ext="${u##*.}"
  case "$ext" in
    jpg|jpeg|png|webp|gif) : ;;
    *) ext=jpg ;;
  esac
  if curl -sSL --max-time 20 "$u" -o ".media/img_$i.$ext"; then
    echo "Saved .media/img_$i.$ext"
  else
    echo "Failed to download $u"
  fi
  i=$((i+1))
done

ls -lh .media/
