#!/bin/bash
# Usage: render_part.sh START END NAME  -> renders frames [START,END) and writes parts/NAME.mp4
set -e
cd "$(dirname "$0")"
fc-list | grep -qi "Inter" || (apt-get install -y fonts-inter >/dev/null 2>&1 || true)
node drive.js frames "$1" "$2" 1 0 "f_$3"
mkdir -p parts
ffmpeg -y -v error -framerate 30 -start_number "$1" -i "f_$3/%05d.jpg" -frames:v $(( $2 - $1 )) -c:v libx264 -preset medium -crf 14 -pix_fmt yuv420p -r 30 "parts/$3.mp4"
ffprobe -v error -count_frames -select_streams v:0 -show_entries stream=nb_read_frames -of csv=p=0 "parts/$3.mp4"
