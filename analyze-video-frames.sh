#!/bin/sh

[ "$1" ] || {
  echo "Please specify video file or stream URL to analyze."
  exit 1
}
ffprobe -show_frames -skip_frame nointra -select_streams v:0 "$1"
