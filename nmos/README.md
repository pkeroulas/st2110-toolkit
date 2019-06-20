# NMOS tools:

# Overview

The idea is to combine a NMOS node instance and a media application to
build a pure software receiver controlled by IS-05.

* implementation for NMOS virtual node is [Sony nmos-cpp](https://github.com/sony/nmos-cpp). Provided Dockerfile generates a Centos-based image dedicated toi this node.
* the media application is our present ffmpeg transcoder

# Scripts

* nmos_node.py: NMOS node class implementation with API calls
* node_controller.py: start/stop a rx/tx node given its IP
* node_connection.py: establish a IS-05 connection between a sender and a receiver
* node_poller.py: poll virtual node connection API, get SDPs, craft SDP file and start/stop ffmpeg-based transcoder

# Setup

TODO

# Execution:

Run run Sony virtual node:

```sh
~/nmos-cpp/Development/build/nmos-cpp-node ~/st2110_toolkit/nmos/nmos-cpp-ffmpeg-mdns-config.json
```

Run the node poller on the same host:

```sh
~/st2110_toolkit/nmos/node_poller.py localhost
```

Establish a connection from sender (192.168.39.12):

```sh
~/st2110_toolkit/nmos/node_connection.py 192.168.39.12 localhost start
```

Refer to general documention to setup the transcoder.

Disable the receiver node:

```sh
~/st2110_toolkit/nmos/node_controller.py localhost rx start
```

# Misc

* Embrionix discovery and registration works only in mdns
* Riedel client is bugged when patching receivers
* port 80 means sudo on Ubunutu 18
* ffmpeg uses management iface by default except if route was prior added, which requires ./network_setup.sh which means sudo
* be carefull of the IP exposed by virtual node, it could be mgt IP, the client can be confused
* video SDP and audio SDP have to be combined into a single file to work with ffmpeg but it's not allow by ST2110.
