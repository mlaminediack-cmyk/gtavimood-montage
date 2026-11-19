#!/usr/bin/env bash
set -euo pipefail
sudo apt-get update -qq && sudo apt-get install -y -qq ffmpeg fonts-dejavu-core
ID="$1"; NAME="$2"; FMT="$3"; CAPTION="$4"; MINSEC="${5:-0}"; OUTRO="${6:-@gtavimood}"
pip install -q --break-system-packages gdown
gdown "https://drive.google.com/uc?id=${ID}" -O src.mp4

if [ "$FMT" = vertical ]; then W=1080; H=1920; FS=56; else W=1920; H=1080; FS=44; fi
FONT=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf
printf '%s' "$CAPTION" > cap.txt
printf '%s' "$OUTRO" > outro.txt

DUR=$(ffprobe -v error -show_entries format=duration -of csv=p=0 src.mp4)
LOOP=$(python3 -c "import math;d=float('$DUR');m=float('$MINSEC');print(max(0,math.ceil(m/d)-1) if m>0 and d<m else 0)")
HASA=$(ffprobe -v error -select_streams a -show_entries stream=codec_type -of csv=p=0 src.mp4 | head -1 || true)

VF="scale=${W}:${H}:force_original_aspect_ratio=decrease,pad=${W}:${H}:(ow-iw)/2:(oh-ih)/2:black,setsar=1,fps=30,drawtext=fontfile=${FONT}:textfile=cap.txt:fontsize=${FS}:fontcolor=white:borderw=4:bordercolor=black:x=(w-text_w)/2:y=h-text_h-${H}*0.05,format=yuv420p"

if [ -n "$HASA" ]; then
  ffmpeg -y -stream_loop "$LOOP" -i src.mp4 -vf "$VF" -c:v libx264 -preset veryfast -crf 23 -c:a aac -ar 48000 -ac 2 main.mp4
else
  ffmpeg -y -stream_loop "$LOOP" -i src.mp4 -f lavfi -i anullsrc=r=48000:cl=stereo -vf "$VF" -map 0:v -map 1:a -shortest -c:v libx264 -preset veryfast -crf 23 -c:a aac main.mp4
fi

ffmpeg -y -f lavfi -i "color=c=black:s=${W}x${H}:d=3:r=30" -f lavfi -i anullsrc=r=48000:cl=stereo -t 3 \
  -vf "drawtext=fontfile=${FONT}:textfile=outro.txt:fontsize=$((FS+14)):fontcolor=0xFF4FA3:borderw=3:bordercolor=black:x=(w-text_w)/2:y=(h-text_h)/2,format=yuv420p" \
  -c:v libx264 -preset veryfast -crf 23 -c:a aac -ar 48000 -ac 2 -shortest outro.mp4

printf "file 'main.mp4'\nfile 'outro.mp4'\n" > list.txt
ffmpeg -y -f concat -safe 0 -i list.txt -c copy "${NAME}.mp4"

gh release delete "$NAME" --repo "$GITHUB_REPOSITORY" --yes --cleanup-tag 2>/dev/null || true
gh release create "$NAME" "${NAME}.mp4" --repo "$GITHUB_REPOSITORY" --title "$NAME" --notes "Montage GTA VI MOOD"
echo "URL: https://github.com/${GITHUB_REPOSITORY}/releases/download/${NAME}/${NAME}.mp4"
