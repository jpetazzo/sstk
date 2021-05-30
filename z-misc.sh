sstk

gst_test_mpeg2_udp() {
	gst-launch-1.0
		videotestsrc is-live=true \
		! video/x-raw,width=1280,height=720 \
		! mpeg2enc \
		! udpsink host=10.0.0.20 port=1234
}

gst_webcam_mpeg2_udp() {
	# Doesn't seem to work super well though
	gst-launch-1.0
		v4l2src \
		! image/jpeg,width=1920,height=1080 \
		! queue \
		! jpegdec \
		! mpeg2enc \
		! udpsink host=10.0.0.20 port=1234
}

gst_udp_mpeg2_show() {
	# Receive an MPEG2 stream as encoded by the helpers above
	gst-launch-1.0 -v \
		udpsrc port=1234 \
		! mpegvideoparse \
		! mpeg2dec \
		! autovideosink
}

gst_webcam_mpeg2_rtp() {
	# This seems to work better, for a couple of reasons:
	# 1. We send the "sequence header" thing at every GOP, so the
	#    stream can resync (I suppose?)
	# 2. We send a properly packetized RTP stream instead of raw
	#    MPEG essence stream
	gst-launch-1.0 -v \
		v4l2src device=/dev/video2  \
		! "image/jpeg, width=(int)640, height=(int)360, pixel-aspect-ratio=(fraction)1/1, framerate=(fraction)30/1" \
		! jpegdec \
		! mpeg2enc sequence-header-every-gop=true \
		! mpegvideoparse \
		! mpegtsmux \
		! rtpmp2tpay \
		! udpsink host=10.0.0.20 port=1234

}

gst_rtp_mpeg2_show() {
	# receive it
	gst-launch-1.0 -v \
		udpsrc port=1234 caps="application/x-rtp,payload=33" \
		! queue \
		! rtpmp2tdepay \
		! tsdemux \
		! mpeg2dec \
		! autovideosink
}

gst_show_v4l2_info() {
	GST_DEBUG=v4l2src:DEBUG gst-launch-1.0 v4l2src device=/dev/video0
	GST_DEBUG=v4l2src:DEBUG \
		gst-launch-1.0 v4l2src device=/dev/video2 2>&1 \
		| grep "sorted and normalized" | tr ";" "\n"	
}
