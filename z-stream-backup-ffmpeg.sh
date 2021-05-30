#!/bin/sh

#SERVER=18.184.91.145
#SERVER=3.125.205.7
#SERVER=18.196.3.222
SERVER=video.container.training
APP=live
CODEC_SOFTWARE="-c:v libx264 -preset ultrafast -tune:v:0 zerolatency -profile:v baseline"
CODEC_HARDWARE="-c:v h264_nvenc -preset ll -profile:v baseline -rc cbr_ld_hq"

FPS=30

# Reminder: to see alsa devices and their numbers, run "arecord -l"
AUDIO_INPUT_NAME=ATR2USB
#AUDIO_INPUT_NAME=UDULTCDL
#AUDIO_INPUT_NAME=C4K
CARD_NUMBER=
for CARD in /sys/class/sound/card*; do
	if grep -q "$AUDIO_INPUT_NAME" $CARD/id; then
		CARD_NUMBER=$(cat $CARD/number)
		echo "Found ALSA card $AUDIO_INPUT_NAME (number $CARD_NUMBER)."
		AUDIO_INPUT_ALSA="-f alsa -ac 2 -i hw:$CARD_NUMBER,0"
		break
	fi
done
if [ "$CARD_NUMBER" = "" ]; then
	echo "Could not find ALSA card $AUDIO_INPUT_NAME. Aborting."
	exit 1
fi
AUDIO_INPUT_MUSIC="-re -i Downloads/Sonnentanz.m4a"
AUDIO_INPUT_PULSE="-f pulse -i alsa_input.usb-UC_MIC_ATR2USB-00.analog-stereo"
AUDIO_INPUT_ALSA_DEFAULT="-f alsa -i default"

VIDEO_INPUT_OBS="-f v4l2 -frame_size 1920x1080 -framerate $FPS -i /dev/video9"
VIDEO_INPUT_TEST="-re -f lavfi -i testsrc=size=hd1080:rate=30:decimals=1"
VIDEO_INPUT_LOOP="-re -fflags +genpts -stream_loop -1 -i Downloads/streamingtest.mkv"
VIDEO_INPUT_CLOCK="-re -f lavfi -i color=color=white:s=hd1080:r=30[white];movie=CLOCK.JPG,scale=hd1080:force_original_aspect_ratio=decrease[img];[white][img]overlay,drawtext=text=%{localtime}:fontcolor=black:x=w-text_w-96:y=(h-text_h)/2:fontsize=48,drawtext=text=Playing→:fontcolor=black:x=w-text_w-32:y=h-3*text_h-32:fontsize=32,drawtext=textfile=title.txt:fontcolor=black:x=w-text_w-32:y=h-text_h-32:fontsize=32'"

AUDIO_INPUT="$AUDIO_INPUT_ALSA"
VIDEO_INPUT="$VIDEO_INPUT_OBS"

case "$1" in
	stream-camera-and-record)
		;;
	stream-test-without-recording)
		AUDIO_INPUT="$AUDIO_INPUT_MUSIC"
		VIDEO_INPUT="$VIDEO_INPUT_TEST"
		;;
esac


STREAM_1=stream1
STREAM_2=stream2
STREAM_3=stream3
STREAM_4=stream4

#SERVER=live.twitch.tv
#APP=app
#STREAM_1=live_525421637_82n5aeTvaykARmUFym3ZXAjM6AQwdZ

ENCODE_AUDIO="
	-c:a aac
	-map 0:a:0 -ac:a:0 1 -b:a:0 128k
	-map 0:a:0 -ac:a:1 1 -b:a:1 64k
	-map 0:a:0 -ac:a:2 1 -b:a:2 48k
	"

ENCODE_VIDEO="
	$CODEC_HARDWARE
        -filter_complex format=yuv420p,split=2[s1][30fps];[s1]fps=fps=15[15fps];[30fps]split=2[30fps1][30fps2];[15fps]split=2[15fps1][15fps2]
	-map [30fps1] -b:v:0 3800k -maxrate:v:0 3800k -bufsize:v:0 3800k -g $((1*$FPS))
	-map [30fps2] -b:v:1 1800k -maxrate:v:1 1800k -bufsize:v:1 1800k -g $((1*$FPS))
	-map [15fps1] -b:v:2  900k -maxrate:v:2  900k -bufsize:v:2  900k -g $((1*$FPS))
	-map [15fps2] -b:v:3  400k -maxrate:v:3  400k -bufsize:v:3  400k -g $((1*$FPS))
	"

OUTPUT="-f tee -flags +global_header"
OUTPUT="$OUTPUT [f=mpegts:select=\'a:0,v:0\']udp://10.0.0.20:1234"
if [ "$1" = "stream-camera-and-record" ]; then
	mkdir -p recordings
	FILENAME=recordings/$(date +%Y-%m-%d_%H:%M:%S).mkv
	OUTPUT="$OUTPUT|[select=\'a:0,v:0\']$FILENAME"
fi
OUTPUT="$OUTPUT|[f=flv:select=\'a:0,v:0\']rtmp://$SERVER/$APP/$STREAM_1"
OUTPUT="$OUTPUT|[f=flv:select=\'a:0,v:1\']rtmp://$SERVER/$APP/$STREAM_2"
OUTPUT="$OUTPUT|[f=flv:select=\'a:1,v:2\']rtmp://$SERVER/$APP/$STREAM_3"
OUTPUT="$OUTPUT|[f=flv:select=\'a:2,v:3\']rtmp://$SERVER/$APP/$STREAM_4"

FFMPEG="ffmpeg
	-hide_banner
	-thread_queue_size 1024 $AUDIO_INPUT
	-thread_queue_size 1024 $VIDEO_INPUT
	$ENCODE_AUDIO
	$ENCODE_VIDEO
	$OUTPUT
	"

	#$ENCODE_4000K -f flv rtmp://$SERVER/$APP/$STREAM_1
	#$ENCODE_4000K -f flv rtmp://$SERVER/$APP/$STREAM_2

case "$1" in
	sound-check)
		ffplay $AUDIO_INPUT
		;;
	stream-camera-and-record)
		xset s off
		xset -dpms
		$FFMPEG
		xset s on
		xset +dpms
		;;
	stream-test-without-recording)
		$FFMPEG
		;;
	*)
		echo "Please specify 'sound-check' or 'stream-camera-and-record' or 'stream-test-without-recording'."
		echo "If device is open by pulseaudio, here is how to free it:"
		echo "pacmd list-modules | grep -e index -e $AUDIO_INPUT_NAME"
		echo "pacmd unload-module XX # use number shown above"
		;;
esac
