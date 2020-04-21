# NMOS tools

## Overview

The idea is to combine a NMOS node instance and a media application to
build a pure software receiver controlled by IS-05.

* implementation for NMOS virtual node is [Sony nmos-cpp](https://github.com/sony/nmos-cpp). Provided Dockerfile generates a Centos-based image dedicated to this node.
* the media application is our present FFmpeg transcoder

## Scripts

* nmos_node.py: NMOS node class implementation with API calls
* node_poller.py:
    - poll Rx status from a virtual node using connection API (IS-05)
    - on RX activation, pull SDPs and adapt for FFmpeg
    - start/stop FFmpeg-based transcoder
* node_connection.py: establish a IS-05 connection between a sender and a receiver
    - fetche transport file of the 1st video and 1st audio flows of the sender device
    - pushe to the consport files to corresponding flows of the receiver device
* node_controller.py: controls (start/stop, rx/tx) the nmos-cpp-node

## Execute:

Run run Sony virtual node:

```sh
~/nmos-cpp/Development/build/nmos-cpp-node ~/st2110_toolkit/nmos/config/nmos-cpp-ffmpeg-mdns-config.json
```

Run the node poller on the same host:

```sh
~/st2110_toolkit/nmos/node_poller.py <nmos-cpp-node-IP>
```

Establish a connection from NMOS-capable sender:

```sh
~/st2110_toolkit/nmos/node_connection.py <sender-IP> <nmos-cpp-node-IP> start
```

Disable the receiver node:

```sh
~/st2110_toolkit/nmos/node_controller.py <nmos-cpp-node-IP> rx stop
```

## TODO

* Merge node_controller in node_connection
* Except from the poller , it's probably a better idea to re-use [nmos-testing](https://github.com/AMWA-TV/nmos-testing)

## Misc

* Binding cpp-nmos connection API to port 80 needs sudo on Ubunutu 18.
* be carefull of the IPs exposed by virtual node, it could be mgmt IP, the client can be confused
* video SDP and audio SDP have to be combined into a single file to work with FFmpeg but it's not allow by ST2110.
