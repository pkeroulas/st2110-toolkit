# PTP utilities

A good synchronization is mandatory to make a capture device precise
while timestamping arriving packets.

## ptp4l

There are tones of online documentation to setup `ptp4l` to sync
NIC clock to a grand master clock and then, to use `pch2sys` to sync
system/OS time to NIC clock.

## Hardware Clock

`testptp` is can interact with NIC HW clock to set it manually and get
offset with system time. It was really usefull to verify that NIC was
the actual source of timestamp for `tcpdump`/`libcap`.

* get this utility from [Linux sources](https://elixir.bootlin.com/linux/v4.8.17/source/Documentation/ptp/testptp.c).
* compile it using `librt`
* make sure `phc2sys` is off
* find the proper ptp device id
* use the utility

```sh
$ gcc -o testptp testptp.c -lrt
$ sudo ethtool -T enp101s0f1 | grep PTP
PTP Hardware Clock: 3
$ ./testptp -d /dev/ptp3 -T 3333333
set time okay
$ ./testptp -d /dev/ptp3 -g
clock time: 3333336.759303339 or Sun Feb  8 08:55:36 1970
```

## linuxptp_sync_graph.py

This tool measures the precision of a system clock regarding of a grand
master.  This script which is supposed to run on a workstation executes
`pmc` (Ptp Management Client) on remote a node to provide time offset and
plot it on a graph.

## TODOs

In case of high traffic, Mellanox NIC can steer PTP in a dedicated
buffer: https://community.mellanox.com/s/article/howto-steer-ptp-traffic-to-single-rx-ring--via-ethtool-x

Refine linuxptp_sync_graph and make it more convenient.
