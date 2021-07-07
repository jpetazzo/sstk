#!/bin/sh

if ! [ "$1" ]; then
  echo "
This script will cut a video file into segments.
It takes a cue sheet as its first and only argument.
The cue sheet should look like this:

INPUT=2021-06-13_07:22:19.mkv

_cut_ 5855 9820 reblaze-day-1-part-1
_cut_ 10218 13550 reblaze-day-1-part-2
_cut_ 13900 16800 reblaze-day-1-part-3
_cut_ 20384 24217 reblaze-day-1-part-4
_cut_ 24620 27158 reblaze-day-1-part-5

It will cut each scene from the closest previous I-frame,
to the closest next I-frame. Cutting on I-frames allows to
cut without transcoding; which is superfast; but it will
include a few extra seconds before and after the cut points.
"
  exit 1
fi

set -ue

_cut_() {
  START=$1
  END=$2
  OUTPUT=$3

  if ! [ -f $INPUT.iframes ]; then
    ffprobe -show_frames -skip_frame nointra -select_streams v:0 $INPUT \
      | grep ^pkt_pts_time | cut -d= -f2 \
      > $INPUT.iframes
  fi
  START_IFR=$(python -c "import sys; print(max(float(s) for s in sys.stdin if float(s)<$START))" < $INPUT.iframes)
  END_IFR=$(python -c "import sys; print(min(float(s) for s in sys.stdin if float(s)>$END))" < $INPUT.iframes)
  DURATION=$(python -c "print($END_IFR-$START_IFR)")

  ffmpeg -ss $START_IFR -t $DURATION -i $INPUT -c:a copy -c:v copy $OUTPUT.mp4
}

. ./$1
