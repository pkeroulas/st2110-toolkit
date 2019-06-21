# NMOS tools

## Overview

The idea is to combine a NMOS node instance and a media application to
build a pure software receiver controlled by IS-05.

* implementation for NMOS virtual node is [Sony nmos-cpp](https://github.com/sony/nmos-cpp). Provided Dockerfile generates a Centos-based image dedicated toi this node.
* the media application is our present ffmpeg transcoder

## Scripts

* nmos_node.py: NMOS node class implementation with API calls
* node_controller.py: start/stop a rx/tx node given its IP
* node_connection.py: establish a IS-05 connection between a sender and a receiver
* node_poller.py: poll virtual node connection API, get SDPs, craft SDP file and start/stop ffmpeg-based transcoder

## Setup

TODO

### DNS-SD

[AMWA instructions:](https://github.com/AMWA-TV/nmos/wiki/DNS-Servers)

dnsmasq.conf contains:

* DNS entries (with ports)
* the domain name (== nxdomain and != FQDN)
* the local domain (which tell to search in /etc/hosts which contains querySD and registrationSD)
* a ref to the 'master' server in /etc/resolv.something.conf, for request forward for non local names
* log_query option for troubleshooting

Devices should get the IP of this DNS server manually or through DHCP

## Execution:

Run run Sony virtual node:

```sh
~/nmos-cpp/Development/build/nmos-cpp-node ~/st2110_toolkit/nmos/config/nmos-cpp-ffmpeg-mdns-config.json
```

Run the node poller on the same host:

```sh
~/st2110_toolkit/nmos/node_poller.py localhost
```

Establish a connection from sender (192.168.39.12):

```sh
~/st2110_toolkit/nmos/node_connection.py 192.168.39.12 localhost start
```

This scripts fetch transport file of the 1st video and 1st audio tracks
of the sender device and pushes them to the corresponding track of the
receiver device.

Refer to general documention to setup the transcoder.

Disable the receiver node:

```sh
~/st2110_toolkit/nmos/node_controller.py localhost rx start
```

## TODO

* try to apply CAP_NET_BIND_SERVICE capability to be able to listen on port 80
* FFmpeg should stream HLS to http server

## Misc

* The current version of Embrionix encapsulator can't discover registry with DNS-SD
* Riedel Explorer is bugged when patching receivers using IS-05, the issue is reported
* Riedel Explorer use port 80 only for IS-05
* Binding cpp-nmos connection API to port 80 needs sudo on Ubunutu 18.
* be carefull of the IPs exposed by virtual node, it could be mgmt IP, the client can be confused
* Run virtual node and registry on separated hosts
* video SDP and audio SDP have to be combined into a single file to work with ffmpeg but it's not allow by ST2110.
