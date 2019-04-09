# ST-2110 software toolkit

Author: [Patrick Keroulas](mailto:patrick.keroulas@radio-canada.ca)

This toolkit provides scripts and config to test, monitor and transcode ST-2110 streams.
Features:

* setup network (routes, firewall)
* setup NIC (Rx buffer size, checksum, timestamping)
* get SDP file from Embrionix encapsulator
* capture streams from SDP
* transcode st2110-to-h264 from live feed described SDP
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
address. The result is a SDP file which contains the selected flows
provided by the source. See [flow description.](./doc/embrionix.md) for
more details.

```sh
$ ./get_sdp.py <sender_IP> <flows>
$ ./get_sdp.py 192.168.1.176 0 2 18
[...]
------------------------------------------------------------------------
SDP written to emb_encap_176.sdp
```

[Embrinonix SDP example.](./doc/sdp.sample)

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
Scaling and encoding: cpu.
Audio codec is aac.
[...]
$ ./transcoder.sh log
[...]
$ ./transcoder.sh stop
==================== Stop ... ====================
```

If error message is returned, look at the actual ffmpeg command line at
the beginning of the log file or see 'Troubleshoot' section below.

Script constants, like destination IP, can be overridden by conf file,
i.e. `/etc/st2110.conf`. See sample `./config/st2110.conf` for details.

On a monitoring host:

```sh
$ ffplay udp://@0.0.0.0:5000
$ vlc --network-caching 4000  udp://@0.0.0.0:5000
```

## FFmpeg options

Without '-pass 1', the CPU usage is way higher and the audio breaks
after a few seconds, at least for rtmp output. The 1st con of the option is
that the output bitrate might less precise. And the generated passlog
file is quite large (~10GB/day). The 'monitor' function of the transcoder
checks the size of this file and restarts ffmpeg if needed.

## Hardware acceleration for transcoding

[Nvidia setup.](./doc/hw_encoding.md)

## Transcoding performance

[Measurments](./doc/transcoder_perf.md) with CPU vs GPU.

## Trancoding ancillary data (SMPTE ST 2110-40)

ffmpeg shows some limitations in [transcoding closed
caption](./doc/closed_captions.md).

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
[...]
```

You can validate that the multicast IGMP group is joined and that data
is received thanks to the socket reader:

```sh
$ cd misc/
$ gcc -o socket_reader -std=c99 socket_reader.c
$ ./socket_reader -g 225.16.0.1 -p 20000 -i 172.30.64.118
[...]
```

Note that in certain setup, the initial join may take several second.

When capturing, if `smcroute` returns this error, restart the daemon:

```
Daemon error: Join multicast group, unknown interface eth0
$ sudo /etc/init.d/smcroute restart
```

## Todos

* install: make it work for Debian
* separate NIC setup from network setup
* document Mellanox NIC installation
* transcoder: test multiple outputs
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
