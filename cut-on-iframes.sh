#!/bin/sh

if ! [ "$1" ]; then
  echo "
This script will cut a video file into segments.
First argument should be the base name of the cue sheet.
The cue sheet will be created if it doesn't exist.

This script cuts each scene from the closest previous I-frame,
to the closest next I-frame. Cutting on I-frames allows to
cut without transcoding; which is superfast; but it will
include a few extra seconds before and after the cut points.
"
  exit 1
fi

BASE="$1"
CUESHEET="$1.txt"
touch "$CUESHEET"

while true; do
  echo "This is the content of the cue sheet:"
  echo "<BEGIN>"
  cat "$CUESHEET"
  echo "<END>"
  echo "We have the following MKV files:"
  ls -l *.mkv
  echo "Please enter a MKV file to add, or nothing to cut."
  read MKVFILE
  if [ "$MKVFILE" ]; then
    echo "INPUT=$MKVFILE" >> "$CUESHEET"
    echo "_cut_ X X $BASE-pX" >> "$CUESHEET"
    subl "$CUESHEET"
    mplayer -osdlevel 3 "$MKVFILE"
  else
    break
  fi
done

_cut_() {
  START=$1
  END=$2
  OUTPUT=$3
  SALT=$(base64 /dev/urandom | head -c4)

  if ! [ -f $INPUT.iframes ]; then
    ffprobe -show_frames -skip_frame nointra -select_streams v:0 $INPUT \
      | grep ^pkt_pts_time | cut -d= -f2 \
      > $INPUT.iframes
  fi
  START_IFR=$(python -c "import sys; print(max(float(s) for s in sys.stdin if float(s)<$START))" < $INPUT.iframes)
  END_IFR=$(python -c "import sys; print(min(float(s) for s in sys.stdin if float(s)>$END))" < $INPUT.iframes)
  DURATION=$(python -c "print($END_IFR-$START_IFR)")

  ffmpeg -ss $START_IFR -t $DURATION -i $INPUT -c:a copy -c:v copy $OUTPUT-$SALT.mp4
}

set -ue

. "./$CUESHEET"

rsync -Pav *.mp4 highfive:portal/www/html/replay/

for F in *.mp4; do
  echo https://highfive.container.training/replay/$F
done
