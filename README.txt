-------------------------------------------------------------------
ST-2110 software toolkit
-------------------------------------------------------------------

Author: Patrick Keroulas <patrick.keroulas@radio-canada.ca>

This collection of tools performs tasks that can't be integrated in
FFmpeg for ST 2110 transcoding:

* install FFmpeg and dependencies for Centos
* setup network:
  - route for multicast streams
  - route to unicast source
  - NIC parameters
  - buffer size
  - etc
* analyse stream content like ptp clock

-------------------------------------------------------------------
Install ffmpeg and dependencies
-------------------------------------------------------------------

Install everything (tools, FFmpeg and all the dependencies) on Centos 7
using the install scrip:

 $ ./install.sh install_all

Or you can install a single component:

 $ ./install.sh install_ffmpeg

-------------------------------------------------------------------
Get an SDP file:
-------------------------------------------------------------------

FFmpeg needs an SDP file for stream description. A python script grabs
the SDP from an Embrionix encapsulator using its unicast address:

 $ ./embrionix_sfp_get_sdp.py 172.30.64.161

Make an SDP file from the entire or the partial output.
Example:

 $ cat file.sdp
 v=0
 o=- 1443716955 1443716955 IN IP4 172.30.64.176
 s=st2110 stream

 t=0 0
 m=audio 20000 RTP/AVP 97
 c=IN IP4 225.0.1.16/64
 a=source-filter: incl IN IP4 225.0.1.16 172.30.64.176
 a=rtpmap:97 L24/48000/8
 a=mediaclk:direct=0 rate=48000
 a=framecount:48
 a=ptime:1
 a=ts-refclk:ptp=IEEE1588-2008:00-02-c5-ff-fe-21-60-5c:127

 t=0 0
 m=video 20000 RTP/AVP 96
 c=IN IP4 225.16.0.16/64
 a=source-filter: incl IN IP4 225.16.0.16 172.30.64.176
 a=rtpmap:96 raw/90000
 a=fmtp:96 sampling=YCbCr-4:2:2; width=1920; height=1080; exactframerate=30000/1001; depth=10; TCS=SDR; colorimetry=BT709; PM=2110GPM; SSN=ST2110-20:2017; TP=2110TPN; interlace=1
 a=mediaclk:direct=0
 a=ts-refclk:ptp=IEEE1588-2008:00-02-c5-ff-fe-21-60-5c:127


-------------------------------------------------------------------
Transcode
-------------------------------------------------------------------

Use ./transcode.sh to start the transcoder by giving the destination
monitor IP and port:

 $ ./transcoder.sh help
 $ ./transcoder.sh setup ens224 file.sdp

If error message is returned, see 'Troubleshoot' section below.

 $ ./transcoder.sh start 192.168.1.1:5000 file.sdp
 $ ./transcoder.sh log
 $ ./transcoder.sh stop

-------------------------------------------------------------------
Troubleshoot
-------------------------------------------------------------------

Find your live media interface name and execute:

 $ sudo ./network_setup.sh file.sdp <interface>

You can validate that the multicast IGMP group is joined and that data
is received thanks to the socket reader:

 $ gcc -o socket_reader -std=c99 socket_reader.c
 $./socket_reader -g 225.16.0.1 -p 20000 -i 172.30.64.118

-------------------------------------------------------------------
TODO
-------------------------------------------------------------------

* separate NIC setup from network setup
* add script/doc for GPU installation

-------------------------------------------------------------------
Additional resources
-------------------------------------------------------------------

Fox Network provides Wireshark dissectors:
* https://github.com/FOXNEOAdvancedTechnology/smpte2110-20-dissector
* https://github.com/FOXNEOAdvancedTechnology/smpte2110-40-dissector

And EBU and CBC provides pcap analyser: Live IP Sowtware Toolkit
* https://github.com/ebu/pi-list
* http://list.ebu.io/login
