# ST-2110 software toolkit

Author: [Patrick Keroulas](mailto:patrick.keroulas@radio-canada.ca)

This toolkit provides scripts and config to test, monitor and transcode SMPTE ST 2110 streams.
Features:

* setup network (routes, firewall) and Mellanox NIC (Rx buffer size, checksum, timestamping)
* capture streams described by SDP file fetched from Embrionix encapsulator
* transcode st2110-to-h264 from live feeds described by same SDP
* integration resources for [EBU-LIST](https://tech.ebu.ch/list)
* misc pcap tools
* analyse stream content like PTP clock

Sponsored by:

![logo](https://site-cbc.radio-canada.ca/site/annual-reports/2014-2015/_images/about/services/cbc-radio-canada.png)

Tested distros:
* Centos 7
* Dockerized Centos 7
* Ubuntu 18.04

## Install

Install everything (tools, FFmpeg and all the dependencies) using the install scrip:

```sh
$ ./install.sh <common|transcoder|capture|ebulist|nmos>
```

## Configuration

Both capture and transcoder scripts have default parameters but they can
be overriden by a config filecan to be installed as `/etc/st2110.conf`.
See the sample in `./config/`. This config also provisions EBU-list
server config.

## Capture

[Instructions](https://github.com/pkeroulas/st2110-toolkit/blob/master/capture/README.md) includes network interface configuration.

## Transcode

It is required to go through the capture process before in order to
validate all the underlying layers that fowards a stream to an application.
Then one can use our FFmpeg-based transcoder following this [instructions.](https://github.com/pkeroulas/st2110-toolkit/blob/master/transcoder/README.md)

## EBU-LIST

[Integration guide](https://github.com/pkeroulas/st2110-toolkit/blob/master/ebu-list/README.md) for a complete capture and analysis system.

## NMOS

[README](https://github.com/pkeroulas/st2110-toolkit/blob/master/nmos/README.md) shows a POC for a NMOSisfied transcoder.

## Pcap tools

[Pcap script folder](https://github.com/pkeroulas/st2110-toolkit/blob/master/pcap) contains helper scripts which operate on PCAP files:

* ancillary editor: insert different types of failure in SMPTE ST 291-1 payload
* pkt drop detector: count dropped packets for a given RTP stream
* stream detector: count every (src/dst) IP pair for a given pcap file
* video yuv extractor: convert RFC4175 payload into raw YUV file

## Todos

* deal with transcoder Dockerfile
*nanoseconds ebu-list: fix ptp lock test
    "The rms value reported by ptp4l once the slave has locked with the GM shows the root mean square of the time offset between the PHC and the GM clock. If ptp4l consistently reports rms lower than 100 ns, the PHC is synchronized."
    check_clock.c
* rework`./capture/nic_setup.sh`
* nmos-poller: display ffmpeg status
* ffmpeg: a static route to multicast must be added, why? would it work
  with a route to source IP only? is it possible to tell ffmpeg which
  interface to use

## Additional resources

* [video](https://github.com/FOXNEOAdvancedTechnology/smpte2110-20-dissector)
* [ancillary](https://github.com/FOXNEOAdvancedTechnology/smpte2110-40-dissector)
* [EBU tools](https://github.com/ebu/smpte2110-analyzer)
