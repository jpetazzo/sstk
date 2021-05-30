#!/bin/sh
SS=$1
INFILE=$2
OUTFILE=$3

if ! [ "$OUTFILE" ]; then
  echo "$0 <start-time-in-seconds> <inputfile.mkv> <outputfile.mp4>"
  exit 0
fi

# I benchmarked presets p1-p4-p7:
# p1 does ~900fps, needs 10-20% more bytes than p4 to achieve same quality
# p4 does ~450fps, needs 2-3% more bytes than p7 to achieve same quality
# p7 does ~290fps

# About cq: I tried 26-31-36-41; on 41 I could see some artefacts that
# didn't show up at the other levels. On 26-31-36 I couldn't see artefacts
# (or if I could, they showed at all levels, indicating that they were
# probably in the source material).

ffmpeg -ss $SS \
  -i $2 \
  -c:a copy -c:v h264_nvenc -preset p4 -rc vbr -cq 36 \
  $3

rsync -Pav $3 eu.container.training:portal/www/html/
