#!/bin/sh
# To automatically format this file properly:
# shfmt --indent 2 <script-name.sh>

set -eu

. ./.env

SERVER1=$REMOTE
APP=live
MONITOR=udp://127.0.0.1:1234
#MONITOR=udp://10.0.0.16:1234

# Default to software encoding
CODECINFO="libx264 (CPU)"
HWINIT=
VIDEOFILTER=format=yuv420p
# This one should reduce latency (no B-frames etc) and make the job easier on the decoder, too
CODEC="-c:v libx264 -preset medium -tune:v zerolatency -profile:v baseline"
# But this one would yield higher quality (at the expense of a bit more latency and CPU usage)
#CODEC="-c:v libx264 -preset medium -profile:v main"

# If we detect a seemingly working VAAPI setup, use it
# (this has been written specifically for Intel QuickSync;
# we tried to use h264_qsv but weren't able to get it to work)
if vainfo >/dev/null; then
  CODECINFO="h264_vaapi (Intel GPU and other VAAPI platforms)"
  HWINIT="-hwaccel vaapi -vaapi_device /dev/dri/renderD128"
  CODEC="-c:v h264_vaapi -profile:v main -profile:v:4 high -qp:v:4 25"
  VIDEOFILTER=format=nv12,hwupload
fi

# If we detect an AMD GPU, use AMF (Advanced Media Framework)
if lspci | grep -qw Renoir; then
  CODECINFO="CODEC: h264_amf (AMD GPU)"
  HWINIT=""
  VIDEOFILTER=format=yuv420p
  CODEC="-c:v h264_amf -quality 2 -rc cbr"
  # Another option:
  #CODEC="-c:v h264_amf -profile:v 256 -quality 2 -rc cbr"
  # For reference:
  # -profile:v 256 = constrained_baseline
  # -quality 2 = prefer quality over speed
fi

# If we detect an NVIDIA GPU, use NVENC
if lspci | grep -qw NVIDIA; then
  # Old version of NVENC
  # (Here for reference version only; not used anymore in recent SDKs)
  #CODEC="-c:v h264_nvenc -preset ll -profile:v baseline -rc cbr_ld_hq"
  # New (2021ish) version of NVENC
  CODECINFO="CODEC: h264_nvenc (NVIDIA GPU)"
  HWINIT=""
  VIDEOFILTER=format=yuv420p
  CODEC="
    -c:v   h264_nvenc -tune ll -profile:v baseline -rc cbr
    -c:v:4 h264_nvenc -preset:v:4 p4 -profile:v:4 high -rc:v:4 vbr -cq:v:4 36
    "
fi

echo "$CODECINFO"

FPS=30

# Note: to see alsa devices and their numbers, run "arecord -l"
# Note: to see the device names used here, run "/sys/class/sound/card*/id"
#AUDIO_INPUT_NAME=ATR2USB
#AUDIO_INPUT_NAME=UDULTCDL
#AUDIO_INPUT_NAME=C4K
#AUDIO_INPUT_NAME=PCH
AUDIO_INPUT_NAME=RX
CARD_NUMBER=
for CARD in /sys/class/sound/card*; do
  if grep -q "$AUDIO_INPUT_NAME" $CARD/id; then
    CARD_NUMBER=$(cat $CARD/number)
    echo "AUDIO: type=ALSA, id=$AUDIO_INPUT_NAME, number=$CARD_NUMBER"
    AUDIO_INPUT_ALSA="-f alsa -ac 2 -i hw:$CARD_NUMBER,0"
    PULSE_CARD_NAME=$(pactl list short cards | grep $AUDIO_INPUT_NAME | cut -d"	" -f2)
    if [ "$PULSE_CARD_NAME" ]; then
      PULSE_OFF_CMD="pactl set-card-profile $PULSE_CARD_NAME off"
      PULSE_ON_CMD="pactl set-card-profile $PULSE_CARD_NAME input:analog-stereo"
    else
      echo "Warning: could not find Pulseaudio card corresponding to $AUDIO_INPUT_NAME."
      PULSE_OFF_CMD=""
      PULSE_ON_CMD=""
    fi
    break
  fi
done
if [ "$CARD_NUMBER" = "" ]; then
  echo "Could not find ALSA card $AUDIO_INPUT_NAME. Aborting."
  exit 1
fi
AUDIO_INPUT_MUSIC="-re -i Downloads/Sonnentanz.m4a"
AUDIO_INPUT_PULSE="-f pulse -i alsa_input.usb-UC_MIC_ATR2USB-00.analog-stereo"
AUDIO_INPUT_PULSE="-f pulse -i alsa_input.usb-DJI_Technology_Co.__Ltd._Wireless_Microphone_RX-00.analog-stereo"
AUDIO_INPUT_ALSA_DEFAULT="-f alsa -i default"

OBS_VIRTUAL_DEVICE_NAME="OBS"
OBS_VIRTUAL_DEVICE=""
while [ -z "$OBS_VIRTUAL_DEVICE" ]; do
  for dev in /sys/class/video4linux/*; do
    if [ "$(cat $dev/name)" = "$OBS_VIRTUAL_DEVICE_NAME" ]; then
      OBS_VIRTUAL_DEVICE="/dev/$(basename $dev)"
      echo "VIDEO: type=V4L2, name=$OBS_VIRTUAL_DEVICE_NAME, device=$OBS_VIRTUAL_DEVICE"
      break
    fi
  done
  if [ -z "$OBS_VIRTUAL_DEVICE" ]; then
    echo "Waiting for OBS Virtual Camera device (it has to be named '$OBS_VIRTUAL_DEVICE_NAME')..."
    sleep 1
  fi
done

VIDEO_INPUT_OBS="-f v4l2 -frame_size 1920x1080 -framerate $FPS -i $OBS_VIRTUAL_DEVICE"
VIDEO_INPUT_TEST="-re -f lavfi -i testsrc=size=hd1080:rate=30:decimals=1"
INPUT_LOOP="-re -fflags +genpts -stream_loop -1 -i loop.mkv"
VIDEO_INPUT_CLOCK="-re -f lavfi -i color=color=white:s=hd1080:r=30[white];movie=CLOCK.JPG,scale=hd1080:force_original_aspect_ratio=decrease[img];[white][img]overlay,drawtext=text=%{localtime}:fontcolor=black:x=w-text_w-96:y=(h-text_h)/2:fontsize=48,drawtext=text=Playing→:fontcolor=black:x=w-text_w-32:y=h-3*text_h-32:fontsize=32,drawtext=textfile=title.txt:fontcolor=black:x=w-text_w-32:y=h-text_h-32:fontsize=32'"

AUDIO_INPUT="$AUDIO_INPUT_ALSA"
VIDEO_INPUT="$VIDEO_INPUT_OBS"

INPUT="
	-thread_queue_size 1024 $AUDIO_INPUT
	-thread_queue_size 1024 $VIDEO_INPUT
	"

#INPUT="$INPUT_LOOP"

STREAM_1=stream1
STREAM_2=stream2
STREAM_3=stream3
STREAM_4=stream4

ENCODE_AUDIO="
	-c:a aac
	-map 0:a:0 -ac:a:0 1 -b:a:0 128k
	-map 0:a:0 -ac:a:1 1 -b:a:1 64k
	-map 0:a:0 -ac:a:2 1 -b:a:2 48k
	"

ENCODE_VIDEO="
	$CODEC
	-filter_complex $VIDEOFILTER,split=2[s1][30fps];[s1]fps=fps=15[15fps];[30fps]split=3[30fps1][30fps2][30fps3];[15fps]split=2[15fps1][15fps2]
	-map [30fps1] -b:v:0 4000k -maxrate:v:0 4000k -bufsize:v:0 4000k -g:v:0 $((1 * $FPS))
	-map [30fps2] -b:v:1 2000k -maxrate:v:1 2000k -bufsize:v:1 2000k -g:v:1 $((1 * $FPS))
	-map [15fps1] -b:v:2 1000k -maxrate:v:2 1000k -bufsize:v:2 2000k -g:v:2 $((1 * $FPS))
	-map [15fps2] -b:v:3  500k -maxrate:v:3  600k -bufsize:v:3 1000k -g:v:3 $((1 * $FPS))
	-map [30fps3]
	"

OUTPUT="-f tee -flags +global_header"
OUTPUT="$OUTPUT -use_fifo 1 -fifo_options drop_pkts_on_overflow=true:attempt_recovery=1:recover_any_error=1:restart_with_keyframe=1"
OUTPUT="$OUTPUT [f=mpegts:select=\'v:0\']$MONITOR"

# Comment out these 3 lines to disable recording
mkdir -p recordings
FILENAME=recordings/$(date +%Y-%m-%d_%H:%M:%S).mkv
OUTPUT="$OUTPUT|[select=\'a:0,v:4\']$FILENAME"

OUTPUT="$OUTPUT|[f=flv:select=\'a:0,v:0\']rtmp://$SERVER1/$APP/$STREAM_1"
OUTPUT="$OUTPUT|[f=flv:select=\'a:0,v:1\']rtmp://$SERVER1/$APP/$STREAM_2"
OUTPUT="$OUTPUT|[f=flv:select=\'a:1,v:2\']rtmp://$SERVER1/$APP/$STREAM_3"
OUTPUT="$OUTPUT|[f=flv:select=\'a:2,v:3\']rtmp://$SERVER1/$APP/$STREAM_4"
if [ "${YOUTUBE_STREAM_KEY-}" ]; then
  OUTPUT="$OUTPUT|[f=flv:select=\'a:0,v:1\']rtmp://a.rtmp.youtube.com/live2/$YOUTUBE_STREAM_KEY"
fi
for EXTRA_SERVER in ${EXTRA_SERVERS-}; do
  OUTPUT="$OUTPUT|[f=flv:select=\'a:0,v:0\']rtmp://$EXTRA_SERVER/$APP/$STREAM_1"
  OUTPUT="$OUTPUT|[f=flv:select=\'a:0,v:1\']rtmp://$EXTRA_SERVER/$APP/$STREAM_2"
  OUTPUT="$OUTPUT|[f=flv:select=\'a:1,v:2\']rtmp://$EXTRA_SERVER/$APP/$STREAM_3"
  OUTPUT="$OUTPUT|[f=flv:select=\'a:2,v:3\']rtmp://$EXTRA_SERVER/$APP/$STREAM_4"
done

FFMPEG="ffmpeg
	-hide_banner
	-report
        $HWINIT
	$INPUT
	$ENCODE_AUDIO
	$ENCODE_VIDEO
	$OUTPUT
	"

set +eu

echo "$FFMPEG"

sep () {
  echo "----------------------------------"
}


sep
echo "Press ENTER to start the sound check."
echo "To end the sound check, press 'q'."
sep
read

$PULSE_OFF_CMD
ffplay $AUDIO_INPUT
$PULSE_ON_CMD

sep
echo "Press ENTER to go live, or Ctrl-C to abort now."
echo "To end the live stream, press 'q'."
sep
read

[ "$WAYLAND_DISPLAY" ] || {
  systemctl --user stop xidlehook
  xset s off
  xset -dpms
}
$PULSE_OFF_CMD
systemd-inhibit $FFMPEG
FFRET=$?
$PULSE_ON_CMD

[ "$WAYLAND_DISPLAY" ] || {
  xset s on
  xset +dpms
  systemctl --user start xidlehook
}

if [ "$FFRET" != "0" ]; then
  echo "It looks like there was an error."
  echo "Hint: if the audio device is held by pulseaudio, here is how to free it:"
  echo "pactl list short sources | grep $AUDIO_INPUT_NAME"
  echo "pactl suspend-source XX # use number shown above"
fi
