# ST-2110 software toolkit

Author: [Patrick Keroulas](mailto:patrick.keroulas@radio-canada.ca)

This toolkit provides scripts and config to test, monitor and transcode ST-2110 streams.
Features:

* install tools and dependencies for Centos
* setup network (routes, firewall)
* setup NIC (Rx buffer size, checksum, timestamping)
* capture streams
* transcode st2110-to-h264
* analyse stream content like ptp clock

## Install ffmpeg and dependencies

Install everything (tools, FFmpeg and all the dependencies) on Centos 7
using the install scrip:

```sh
$ ./install.sh install_all
```

Or you can install a single component:

```sh
$ ./install.sh install_ffmpeg
```

## Setup

The capture can work with a config file for easy use, and on the other
hand, the transcoder (FFmpeg) needs an SDP file for stream description.

A python script grabs SDP from Embrionix encapsulator given its unicast
address. The result is 'capture.conf' and and a SDP file which both
contains info for the 1st video, audio, ancillary essences provided by
the source.

```sh
$ ./get_sdp.py <sender_IP>
v=0
o=- 1443716955 1443716955 IN IP4 172.30.64.176
s=st2110 stream
t=0 0
m=video 20000 RTP/AVP 96
c=IN IP4 225.16.0.16/64
a=source-filter: incl IN IP4 225.16.0.16 172.30.64.176
a=rtpmap:96 raw/90000
a=fmtp:96 sampling=YCbCr-4:2:2; width=1920; height=1080; exactframerate=30000/1001; depth=10; TCS=SDR; colorimetry=BT709; PM=2110GPM; SSN=ST2110-20:2017; TP=2110TPN; interlace=1
a=mediaclk:direct=0
a=ts-refclk:ptp=IEEE1588-2008:00-02-c5-ff-fe-21-60-5c:127

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

v=0
o=- 1443716955 1443716955 IN IP4 172.30.64.176
s=st2110 stream
t=0 0
m=video 20000 RTP/AVP 100
c=IN IP4 225.17.0.16/64
a=source-filter: incl IN IP4 225.17.0.16 172.30.64.176
a=rtpmap:100 smpte291/90000
a=fmtp:100 VPID_Code=133
a=mediaclk:direct=0 rate=90000
a=ts-refclk:ptp=IEEE1588-2008:00-02-c5-ff-fe-21-60-5c:127


------------------------------------------------------------------------
SDP written to emb_encap_176.sdp
------------------------------------------------------------------------
IP addresses extracted and written to capture.conf
```

## Transcode

Use ./transcode.sh to start the transcoder by giving the destination
monitor IP and port:

```sh
$ ./transcoder.sh help
$ ./transcoder.sh setup ens224 file.sdp
```

If error message is returned, see 'Troubleshoot' section below.

```sh
$ ./transcoder.sh start 192.168.1.1:5000 file.sdp
$ ./transcoder.sh log
$ ./transcoder.sh stop
```

## Capture

Create a pcap using 'capture.conf'.

```sh
$ sudo ./capture.sh
```

Or join any multicast group and create a pcap file from the incoming stream

```sh
$ sudo ./capture.sh eth0 239.0.0.15 2
```

## Troubleshoot

Find your live media interface name and execute:

```sh
$ sudo ./network_setup.sh file.sdp <interface>
```

You can validate that the multicast IGMP group is joined and that data
is received thanks to the socket reader:

```sh
$ gcc -o socket_reader -std=c99 socket_reader.c
$./socket_reader -g 225.16.0.1 -p 20000 -i 172.30.64.118
```

## Todos

* sdp: parse mcast IP properly
* install: make it work for Debian
* separate NIC setup from network setup
* add script/doc for GPU installation

## Additional resources

Fox Network provides Wireshark dissectors:

* [video](https://github.com/FOXNEOAdvancedTechnology/smpte2110-20-dissector)
* [ancillary](https://github.com/FOXNEOAdvancedTechnology/smpte2110-40-dissector)

And EBU and CBC provides pcap analyser: Live IP Sowtware Toolkit

* [LIST](http://list.ebu.io/login)
* [source](https://github.com/ebu/pi-list)
