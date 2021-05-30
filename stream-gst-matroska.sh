#!/bin/sh

SINK_HOST=portal.container.training
#SINK_HOST=10.0.0.29
SINK_PORT=1234

FILENAME=recordings/$(date +%Y-%m-%d_%H:%M:%S).mkv

PLATFORM=geforce
case "$PLATFORM" in
	geforce)
		PRE_ENCODE_FILTER=""
		VIDEO_ENCODER="nvh264enc preset=low-latency-hq gop-size=30"
		AUDIO_ENCODER=faac
		# This codec expects a bitrate in kb/s.
		BITRATE=""
		;;
	jetson)
		PRE_ENCODE_FILTER="! nvvidconv"
		VIDEO_ENCODER="nvv4l2h264enc iframeinterval=30"
		AUDIO_ENCODER=voaacenc
		# That codec expects a bitrate in bit/s. Fun times.
		BITRATE="000"
		;;
esac

VIDEO_SRC_TEST="videotestsrc ! video/x-raw,width=1920,height=1080,framerate=30/1 ! clockoverlay"
VIDEO_SRC_LIVE="v4l2src device=/dev/video8 ! video/x-raw,width=1920,height=1080,framerate=30/1 ! videoconvert ! video/x-raw,format=I420"

AUDIO_SRC_TEST="multifilesrc location=Sonnentanz.m4a loop=true ! decodebin"
AUDIO_SRC_LIVE="alsasrc device=hw:5"

VIDEO_SRC=$VIDEO_SRC_LIVE
AUDIO_SRC=$AUDIO_SRC_TEST

gst-launch-1.0 -v \
	$VIDEO_SRC \
	! tee name=v \
	v. \
	! queue \
	$PRE_ENCODE_FILTER \
	! tee name=v30fps \
	v. \
	! queue \
	! videorate \
	! video/x-raw,framerate=15/1 \
	$PRE_ENCODE_FILTER \
	! tee name=v15fps \
	v30fps. \
	! queue \
	! $VIDEO_ENCODER bitrate=3800$BITRATE \
        ! video/x-h264,profile=baseline \
	! h264parse \
	! tee name=videorec \
	! queue \
	! mux. \
	v30fps. \
	! queue \
	! $VIDEO_ENCODER bitrate=1900$BITRATE \
        ! video/x-h264,profile=baseline \
	! h264parse \
	! mux. \
	v15fps. \
	! queue \
	! $VIDEO_ENCODER bitrate=900$BITRATE \
        ! video/x-h264,profile=baseline \
	! h264parse \
	! mux. \
	v15fps. \
	! queue \
	! $VIDEO_ENCODER bitrate=400$BITRATE \
        ! video/x-h264,profile=baseline \
	! h264parse \
	! mux. \
	$AUDIO_SRC \
	! audioconvert \
	! audio/x-raw,channels=1 \
	! audioresample \
	! tee name=a \
	a. \
	! queue \
	! $AUDIO_ENCODER bitrate=128000 \
	! tee name=audiorec \
	! queue \
	! mux. \
	a. \
	! queue \
	! $AUDIO_ENCODER bitrate=64000 \
	! mux. \
	a. \
	! queue \
	! $AUDIO_ENCODER bitrate=48000 \
	! mux. \
	a. \
	! queue \
	! opusenc bitrate=128000 \
	! mux. \
	videorec. \
	! queue \
	! filerec. \
	audiorec. \
	! queue \
	! filerec. \
	matroskamux streamable=true name=mux \
	! tcpclientsink host=$SINK_HOST port=$SINK_PORT \
	matroskamux name=filerec \
	! filesink location=$FILENAME \
	#

