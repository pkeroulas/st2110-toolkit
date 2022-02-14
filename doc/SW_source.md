# SMPTE 2110 Software source

If no source available, [gstreamer](https://gstreamer.freedesktop.org/)
can generate adequate streams. The following command:
* generates a video raw signal, 4:2:2 8-bit
* assembles a udp payload of type 102
* streams to multicast @ 239.0.0.0:5005
* generates an audio raw signal, 24-bit linear, 2 channels
* assembles a udp payload of type 103
* streams to multicast @ 239.0.0.0:5007

```
gst-launch-1.0 rtpbin name=rtpbin \
	videotestsrc horizontal-speed=2 !  \
	video/x-raw,width=1920,height=1080,framerate=30/1,format=UYVP ! rtpvrawpay pt=102 ! queue ! \
	rtpbin.send_rtp_sink_0 rtpbin.send_rtp_src_0 ! queue ! \
	udpsink host=239.0.0.0 port=5005 render-delay=0 rtpbin.send_rtcp_src_0 ! \
	udpsink host=239.0.0.0 port=5005 sync=false async=false \
	audiotestsrc ! audioresample ! audioconvert ! \
	rtpL24pay ! application/x-rtp, pt=103, payload=103, clock-rate=48000, channels=2 ! \
	rtpbin.send_rtp_sink_1 rtpbin.send_rtp_src_1 ! \
	udpsink host=239.0.0.0 port=5007 render-delay=0 rtpbin.send_rtcp_src_1 ! \
	udpsink host=239.0.0.0 port=5007 sync=false async=false
```
