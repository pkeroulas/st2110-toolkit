# ST-2110 software toolkit

Author: [Patrick Keroulas](mailto:patrick.keroulas@radio-canada.ca)

This toolkit provides scripts and config to test, monitor and transcode SMPTE ST 2110 streams.
Features:

* setup network (routes, firewall)
* setup NIC (Rx buffer size, checksum, timestamping)
* get SDP file from Embrionix encapsulator
* capture streams from SDP
* transcode st2110-to-h264 from live feed described SDP
* analyse stream content like ptp clock
* provide NMOS setup script
* integration resources for [EBU-LIST](https://tech.ebu.ch/list)

Tested distros:
* Centos 7
* Dockerized Centos 7
* Ubuntu 18.04

Sponsored by:

![logo](https://site-cbc.radio-canada.ca/site/annual-reports/2014-2015/_images/about/services/cbc-radio-canada.png)

## Install

Install everything (tools, FFmpeg and all the dependencies) using the install scrip:

```sh
$ ./install.sh install_all
```

Or you can install a single component:

```sh
$ ./install.sh install_ffmpeg
```

Or build a Docker container:

```sh
docker build -t centos/transcoder:v0 .
```

## Configuration

### NIC

The first thing to do on system startup is to setup the network
interface controller (NIC).

```sh
$ sudo ./capture/nic_setup.sh eth0
[...]
```

### Master config

Both capture and transcoder scripts have default parameters but they can
be overriden by a config filecan to be installed as `/etc/st2110.conf`.
See the sample in `./config/`. This config also provisions EBU-list
server config.

### Stream description: SDP file

ST2110 senders, like Embrionix encap, should provide an SDP file to
describe every produced essences, i.e. RTP streams.

A python script grabs SDP from Embrionix encapsulator given its unicast
address. The result is a SDP file which contains the selected flows
provided by the source. See [flow description.](./doc/embrionix.md) for
more details.

```sh
$ ./capture/get_sdp.py <sender_IP> <flows>
$ ./capture/get_sdp.py 192.168.1.176 0 2 18
[...]
------------------------------------------------------------------------
SDP written to emb_encap_176.sdp
```

[Embrinonix SDP example.](./doc/sdp.sample)

When using some applications like ffmpeg, a wrong interface to perform
the IGMP join to multicast group. Setup the IP routing table fixes.
Firewall rules may also be needed to unblock the traffic from the NIC to
the userspace socket interface. This is all done by this script:

```sh
$ ./capture/network_setup.sh sdp.file
[...]
```

## Transcode

Use ./transcode.sh to start the transcoding service in back ground from
one or multiple SDP files, then show logs and, finally stop the service.

```sh
$ cd ./transcode/
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

### FFmpeg options

Without '-pass 1', the CPU usage is way higher and the audio breaks
after a few seconds, at least for rtmp output. The 1st con of the option is
that the output bitrate might less precise. And the generated passlog
file is quite large (~10GB/day). The 'monitor' function of the transcoder
checks the size of this file and restarts ffmpeg if needed.

### Hardware acceleration for transcoding

[Nvidia setup.](./doc/hw_encoding.md)

### Transcoding performance

[Measurments](./doc/transcoder_perf.md) with CPU vs GPU.

### Trancoding ancillary data (SMPTE ST 2110-40)

ffmpeg shows some limitations in [transcoding closed
caption](./doc/closed_captions.md).

Here are some guidelines for [SCTE-35](./doc/scte_104_to_35.md).

## Capture

If you already have an SDP file, it can be used as an input for the
capture script which parses every RTP streams.

```sh
$ cd ./capture/
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

## EBU-LIST

[Integration guide](./ebu-list/README.md).

## Troubleshoot

Find your live media interface name and execute:

```sh
$ ./capture/network_setup.sh file.sdp
[...]
```

You can validate that the multicast IGMP group is joined and that data
is received thanks to the socket reader:

```sh
$ cd capture/
$ gcc -o socket_reader -std=c99 socket_reader.c
$ ./socket_reader -g 225.16.0.1 -p 20000 -i 172.30.64.118
[...]
```

Validate that the the multicast group is joined through the correct
interface:

```sh
netstat -ng | grep <multicast_group>
```

Note that in certain setup, the initial join may take several second.

When capturing, if `smcroute` returns this error, restart the daemon:

```
Daemon error: Join multicast group, unknown interface eth0
$ sudo /etc/init.d/smcroute restart
```

Measure the udp packet drops:

```sh
netstat -s -u
```

## [NMOS.](./doc/nmos.md)

## Todos

* rework nic_setup.sh
* poller: display ffmpeg status
* ffmpeg: a static route to multicast must be added, why? would it work
  with a route to source IP only? is it possible to tell ffmpeg which
  interface to use
* document Mellanox NIC installation

## Additional resources

Fox Network provides Wireshark dissectors:

* [video](https://github.com/FOXNEOAdvancedTechnology/smpte2110-20-dissector)
* [ancillary](https://github.com/FOXNEOAdvancedTechnology/smpte2110-40-dissector)
* [EBU tools](https://github.com/ebu/smpte2110-analyzer)
