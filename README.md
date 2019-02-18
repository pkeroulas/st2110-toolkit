# ST-2110 software toolkit

Author: [Patrick Keroulas](mailto:patrick.keroulas@radio-canada.ca)

This toolkit provides scripts and config to test, monitor and transcode ST-2110 streams.
Features:

* setup network (routes, firewall)
* setup NIC (Rx buffer size, checksum, timestamping)
* get SDP file from Embrionix encapsulator
* capture streams from SDP
* transcode st2110-to-h264 from SDP
* analyse stream content like ptp clock
* install common tools and ffmpeg dependencies for Centos

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

Both capture and transcoder scripts have default parameters but they can
be overriden by a config filecan to be installed as `/etc/st2110.conf`.
See the sample in `./config/`.

## SDP file as an input

ST2110 senders, like Embrionix encap, should provide an SDP file to
describe every produced essences, i.e. RTP streams.

A python script grabs SDP from Embrionix encapsulator given its unicast
address. The result is a SDP file which contains info for the 1st video,
audio, ancillary essences provided by the source. See 'Embrionix flows'
section for details.

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
```

In some situations, it is necessary to setup the media network interface,
the IP routes and firewall rules:

```sh
$ sudo ./network_setup.sh eth0 sdp.file
[...]
```

## Transcode

Use ./transcode.sh to start the transcoding service in back ground from
one or multiple SDP files, then show logs and, finally stop the service.

```sh
$ ./transcoder.sh help
[...]
$ ./transcoder.sh start file.sdp
==================== Start ... ====================
Transcoding from file.sdp
Scaling and encoding: soft.
Stream available on port 8080 (harcoded in mkserver)
$ ./transcoder.sh log
[...]
$ ./transcoder.sh stop
==================== Stop ... ====================
```

If error message is returned, look at the actual ffmpeg command line at
the begining of the log file or see 'Troubleshoot' section below.

Additional params can be set in the conf file, i.e. `/etc/st2110.conf`.
See sample `./config/st2110.conf` for details.

On a monitoring host:

```sh
$ ffplay <transcoder_IP>:8080
```

## Hardware acceleration for transcoding

Proposed setup for hardware-accelerated scaling and encoding:

* GPU Model: Nvidia Quadro P4000
* GPU arch: Pascal GP104
* Centos: 7
* Kernel + header: 3.10
* Gcc: 4.8.5
* Glibc: 2.17
* CUDA: 10.0
* Nvidia driver: 415.18

### Nvidia driver

* [Linux driver installation guide.](https://linuxconfig.org/how-to-install-the-nvidia-drivers-on-centos-7-linux)
* [Download v415.18](https://www.nvidia.com/Download/driverResults.aspx/140282/en-us)

Verify the driver is loaded:

```sh
$  lsmod | grep nvi
nvidia_drm             39819  0
nvidia_modeset       1035536  1 nvidia_drm
nvidia_uvm            787278  2
nvidia              17251625  758 nvidia_modeset,nvidia_uvm
ipmi_msghandler        46607  2 ipmi_devintf,nvidia
drm_kms_helper        177166  2 vmwgfx,nvidia_drm
drm                   397988  5 ttm,drm_kms_helper,vmwgfx,nvidia_drm
[...]
$ cat /proc/driver/nvidia/version
[...]
$ nvidia-smi
[...]
```

### CUDA SDK

* [Installation guide](https://developer.download.nvidia.com/compute/cuda/10.0/Prod/docs/sidebar/CUDA_Installation_Guide_Linux.pdf)
* [Download v10.0](https://developer.nvidia.com/cuda-downloads?target_os=Linux&target_arch=x86_64&target_distro=CentOS&target_version=7&target_type=rpmnetwork)

Verify that CUDA can talk to GPU card:

```sh
~/cuda-10.0-samples/NVIDIA_CUDA-10.0_Samples/1_Utilities/deviceQuery/deviceQuery
[...]
Device 0: "Quadro P4000"
  CUDA Driver Version / Runtime Version          10.0 / 10.0
[...]
```

### Nvidia codec for ffmpeg:

`NVENC` needs for custom headers maintained outside of `ffmpeg` sources.

[ffmpeg doc for NVENC](https://trac.ffmpeg.org/wiki/HWAccelIntro#NVENC)

## Capture

If you already have an SDP file, it can be used as an input for the
capture script which parses every RTP streams.

```sh
$ sudo ./capture.sh help
[...]
$ sudo ./capture.sh sdp file.sdp
```

Or manually select any multicast group:

```sh
$ sudo ./capture.sh manual 239.0.0.15 2
```

Additional params (capture duration, truncate) can be set in the conf
file, i.e. `/etc/st2110.conf`. See sample `./config/st2110.conf` for
details.

## Troubleshoot

Find your live media interface name and execute:

```sh
$ sudo ./network_setup.sh eth0 file.sdp
```

You can validate that the multicast IGMP group is joined and that data
is received thanks to the socket reader:

```sh
$ gcc -o socket_reader -std=c99 socket_reader.c
$./socket_reader -g 225.16.0.1 -p 20000 -i 172.30.64.118
```

When capturing, if `smcroute` returns this error, restart the daemon:

```
Daemon error: Join multicast group, unknown interface eth0
$ sudo /etc/init.d/smcroute restart
```

## Embrionix flows

Embrionix encapsulator:

* has 2 SDI inputs A and B
* encapsulates 1 video, 8 audio and 1 ancillary essence for each input
* ouputs 2 (1 and 2) RTP streams par essence

The 40 essences are ordered this way:

* video A1 <------------------ selected by get_sdp.py
* video A2
* audio ch1 A1 <-------------- selected by get_sdp.py
* audio ch1 A2
* [...]
* audio ch8 A1
* audio ch8 A2
* ancillary A1 <-------------- selected by get_sdp.py
* ancillary A2
* video B1
* [...]
* ancillary B2

## Todos

* sdp: filter essence properly or at least document structure
* sdp: correct syntax by keeping one "o=", "v=", "t=", "s="
* install: make it work for Debian
* separate NIC setup from network setup
* transcoder: add script for GPU/CUDA setup
* document Mellanox NIC installation
* tcpdump and smcroute without sudo:

```
bin=$(which tcpdump)
sudo groupadd pcap
sudo usermod -a -G pcap $USER
sudo chgrp pcap $bin
sudo setcap cap_net_raw,cap_net_admin=eip $bin
sudo getcap $bin
```

## Additional resources

Fox Network provides Wireshark dissectors:

* [video](https://github.com/FOXNEOAdvancedTechnology/smpte2110-20-dissector)
* [ancillary](https://github.com/FOXNEOAdvancedTechnology/smpte2110-40-dissector)

And EBU and CBC provides pcap analyser: Live IP Sowtware Toolkit

* [LIST](http://list.ebu.io/login)
* [source](https://github.com/ebu/pi-list)
