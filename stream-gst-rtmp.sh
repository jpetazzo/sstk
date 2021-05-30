#!/bin/sh

RTMP=rtmp://live.container.training/live

VIDEO_SRC_TEST="videotestsrc ! video/x-raw,width=1920,height=1080,framerate=30/1 ! clockoverlay"
VIDEO_SRC_LIVE="v4l2src ! video/x-raw,width=1920,height=1080,framerate=60/1 ! videorate ! video/x-raw,framerate=30/1 ! clockoverlay"

AUDIO_SRC_TEST="multifilesrc location=sonnentanz.m4a loop=true ! decodebin"
AUDIO_SRC_LIVE="alsasrc device=hw:2"

VIDEO_SRC=$VIDEO_SRC_LIVE
AUDIO_SRC=$AUDIO_SRC_LIVE

gst-launch-1.0 \
	$VIDEO_SRC \
	! tee name=v \
	v. \
	! queue \
	! nvvidconv \
	! tee name=v30fps \
	v. \
	! queue \
	! videorate \
	! video/x-raw,framerate=15/1 \
	! nvvidconv \
	! tee name=v15fps \
	v30fps. \
	! nvv4l2h264enc bitrate=4000000 iframeinterval=30 \
	! h264parse \
	! stream1. \
	v30fps. \
	! nvv4l2h264enc bitrate=2000000 iframeinterval=30 \
	! h264parse \
	! stream2. \
	v15fps. \
	! nvv4l2h264enc bitrate=1000000 iframeinterval=30 \
	! h264parse \
	! stream3. \
	v15fps. \
	! nvv4l2h264enc bitrate=500000 iframeinterval=30 \
	! h264parse \
	! stream4. \
	$AUDIO_SRC \
	! audioconvert \
	! audioresample \
	! tee name=a \
	a. \
	! voaacenc \
	! stream1. \
	a. \
	! voaacenc \
	! stream2. \
	a. \
	! voaacenc \
	! stream3. \
	a. \
	! voaacenc \
	! stream4. \
	flvmux name=stream1 \
	! rtmpsink location=$RTMP/stream1 \
	flvmux name=stream2 \
	! rtmpsink location=$RTMP/stream2 \
	flvmux name=stream3 \
	! rtmpsink location=$RTMP/stream3 \
	flvmux name=stream4 \
	! rtmpsink location=$RTMP/stream4 \
	#

