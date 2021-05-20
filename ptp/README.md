# PTP utilities

A good synchronization is mandatory to make a capture device precise.
Mellanox NIC capabilities include hardware timestamping of Tx and Rx
packets to allow both a reliable synchronization to PTP grand master
and accurate timestamp in captures.

## ptp4l

There are tones of online documentation to setup `ptp4l` to sync
NIC clock to a master clock and then, use `pch2sys` to sync
system/OS time to NIC clock. Verify that offset are no more than a few
tens of ns.

```
$ journalctl -f | grep 'ptp4\|phc2'
Jan 21 10:07:28 server1-PowerEdge-R540 phc2sys: [601998.702] phc offset        -9 s2 freq   -1108 delay   1100
Jan 21 10:07:28 server1-PowerEdge-R540 ptp4l: [601999.078] rms   20 max   32 freq  -3106 +/-  28 delay   159 +/-   2
Jan 21 10:07:29 server1-PowerEdge-R540 phc2sys: [601999.702] phc offset        25 s2 freq   -1077 delay   1094
Jan 21 10:07:29 server1-PowerEdge-R540 ptp4l: [602000.090] rms   18 max   28 freq  -3107 +/-  24 delay   157 +/-   6
```

## Hardware Clock

It is important to verify that the HW clock on the NIC is the actual
source of timestamp for `tcpdump`/`libcap`. `testptp` can interact with
this clock to manually set and measure both hardware and system time.

```sh
# get your kernel version
$ uname -a
Linux ..... 4.15.0-112-generic ....
# ptp tester from kernel source
$ wget https://raw.githubusercontent.com/torvalds/linux/v4.15/tools/testing/selftests/ptp/testptp.c
# compile it using `librt`
$ gcc -o testptp testptp.c -lrt
# make sure that `ptp4l` and `phc2sys` are off
# find the proper ptp device id
$ sudo ethtool -T enp101s0f1 | grep PTP
PTP Hardware Clock: 3
$ ./testptp -d /dev/ptp3 -T 3333333
set time okay
$ ./testptp -d /dev/ptp3 -g
clock time: 3333336.759303339 or Sun Feb  8 08:55:36 1970
$ ./testptp -d /dev/ptp3 -k 1
system and phc clock time offset request okay
system time: 1589581164.437482989
phc    time: 1589581201.437483653
system time: 1589581164.437484167
system/phc clock time offset is -37000000075 ns
system     clock time delay  is 1178 ns
```

The difference between UTC and International Atomic Time (TAI) is 37 seconds.

Then `tcpdump -j adapter_unsynced ...` will provide capture from 1970
regardless of the local system time. Turn on `ptp4l` to restore PTP
current time.

## linuxptp_sync_graph.py

This tool measures the precision of a system clock regarding of a grand
master. It is supposed to run on a workstation and remotely executes
`pmc` (Ptp Management Client) to provide time offset of remote nodes and
plot on a graph.

## TODOs

In case of high traffic, Mellanox NIC can steer PTP in a dedicated
buffer: https://community.mellanox.com/s/article/howto-steer-ptp-traffic-to-single-rx-ring--via-ethtool-x

Refine linuxptp_sync_graph and make it more convenient.
