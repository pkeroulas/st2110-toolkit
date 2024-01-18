# ST 2110 software toolkit

This toolkit aims at capturing, analysing and transcoding SMPTE ST 2110 streams.

Features:

* capture RTP packets with high precision timestamps
* transcode ST 2110 essences to h264
* provide various pcap tools
* provide a recipe to create a live version of [EBU-LIST](https://tech.ebu.ch/list)
* troubleshoot the network by capturing traffic on remote hosts

```mermaid
  graph TD;
      A-->B;
      A-->C;
      B-->D;
      C-->D;
```

Sponsored by:

![logo](https://site-cbc.radio-canada.ca/site/annual-reports/2014-2015/_images/about/services/cbc-radio-canada.png)

Tested distros:

* Centos 7
* Dockerized Centos 7
* Ubuntu > 20.04

## Install

The repo contains multiple install sub-scripts, use the one in TOP
DIRECTORY ONLY.

```sh
$ ./install.sh
Usage: ./install.sh <section>
sections are:
    * common:       compile tools, network utilities, config
    * ptp:          linuxptp
    * transcoder:   ffmpeg, x264, mp3 and other codecs
    * capture:      dpdk-based capture engine
    * ebulist:      EBU-LIST pcap analyzer, NOT tested for a while
    * nmos:         Sony nmos-cpp node and scripts for SDP patching

Regardless of your setup, please install 'common' section first.
```

## Configuration

Both capture and transcoder scripts have default parameters but they can
be overriden by a config file to be installed as `/etc/st2110.conf`.
See the [sample](./config/st2110.conf). This config also provisions an
EBU-LIST server in live mode, i.e. connected to a ST 2110 network.

## Capture

These [instructions](./capture/README.md)
show how to setup a performant stream capture engine based on Nvidia/Mellanox NIC + DPDK.

[rtcdump](./capture/rtcpdump.sh) is standalone remote capture tool for
generic network issue.

## Transcode

It is required to go through the capture process before in order to
validate all the underlying layers forwards a stream to an application.
Then one can use our FFmpeg-based transcoder following these
[instructions.](./transcoder/README.md)

## EBU-LIST

Follow the [integration guide](./ebu-list/README.md) for a complete capture and analysis solution.

## NMOS

[README](./nmos/README.md) shows a POC for a NMOSisfied transcoder. And
various scripts are propose to get SDP file from source and patch them
to destination.

## Pcap tools

[Pcap folder](./pcap) contains helper scripts which operate on PCAP files:

* ancillary editor: insert different types of failure in SMPTE ST 291-1 payload
* RTP pkt drop detector: count packets and drops for every (src/dst) IP pair found in a given pcap file
* video yuv extractor: convert RFC4175 payload into raw YUV file
* audio extractor: convert AES 67 payload into raw file

Dependencies:

* python3 and pip
* [scapy](https://scapy.net/)
* [bitstruct](https://pypi.org/project/bitstruct/)

## TODO

* test the RFC4175 encoder in `ffmpeg`
* build a docker image for transcoder
* test recent version of `linux-ptp` to validate that `pmc` no longer needs root permission
* rework`./capture/nic_setup.sh`
* nmos-poller: display ffmpeg status

## [Troubleshoot](./doc/troubleshoot.md)

## Additional resources

* [video](https://github.com/FOXNEOAdvancedTechnology/smpte2110-20-dissector)
* [ancillary](https://github.com/FOXNEOAdvancedTechnology/smpte2110-40-dissector)
* [EBU tools](https://github.com/ebu/smpte2110-analyzer)
