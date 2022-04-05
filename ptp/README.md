# linuxptp utilities

A good synchronization is mandatory to make a capture device precise.
Mellanox NIC capabilities include hardware timestamping of Tx and Rx
packets to allow both a reliable synchronization to PTP grand master
and accurate timestamp in captures. The following doc relies on
`linuxptp` which includes 3 utilities:

## ptp4l

`ptp4l` handle PTP traffic to synchronizes the local NIC clock to a
remote master clock:

```
$ ptp4l -f /etc/linuxptp/ptp4l.conf -s -i <iface>
$ journalctl -f | grep 'ptp4\|phc2'
[...] ptp4l: [601999.078] rms   20 max   32 freq  -3106 +/-  28 delay   159 +/-   2
[...] ptp4l: [602000.090] rms   18 max   28 freq  -3107 +/-  24 delay   157 +/-   6
```

Note that all the time values are in nanosec.

## phc2sys

Then `phc2sys` controls system/OS clock to be synced with NIC clock.

```
$ journalctl -f | grep 'ptp4\|phc2'
$ phc2sys -s <iface> -c CLOCK_REALTIME -w -n <ptp_domain>
[...] phc2sys: [601999.702] phc offset        25 s2 freq   -1077 delay   1094
[...] phc2sys: [601998.702] phc offset        -9 s2 freq   -1108 delay   1100
```

## pmc

Show PTP sync status and metrics:

```
sudo pmc -d <ptp_domain> -u -b 2 'GET CURRENT_DATA_SET'
sudo pmc -d <ptp_domain> -u -b 2 'GET PARENT_DATA_SET'
```

Root priviledge is under [discussion](https://www.mail-archive.com/linuxptp-devel@lists.sourceforge.net/msg05540.html)
for 3.1.2. Tested on commit @4d9f44. It works proveded `uds_file_mode 0666`
and a non-default interface (`-i`):

```
pmc -i /tmp/pmc -d 88 -u -b 2 'GET CURRENT_DATA_SET'
```

## Hardware Clock

It is important to verify that the HW clock on the NIC is the actual
source of timestamp for `tcpdump`/`libcap`. Verify that the dev file is
usable.

```sh
$ sudo hwstamp_ctl -i ens224 -r 1
current settings:
tx_type 0
rx_filter 1
SIOCSHWTSTAMP failed: Resource temporarily unavailable # RED FLAG with a Intel in a VM !!!!!!!
$ lsmod | grep pps
pps_core               20480  1 ptp
```

`testptp` can interact with this clock to manually set and measure both hardware and system time.

```sh
$ uname -a # get your kernel version
Linux ..... 4.15.0-112-generic ....
$ wget https://raw.githubusercontent.com/torvalds/linux/v4.15/tools/testing/selftests/ptp/testptp.c # get ptp tester from kernel source
$ gcc -o testptp testptp.c -lrt # compile it using `librt`
# make sure that `ptp4l` and `phc2sys` are off
$ sudo ethtool -T enp101s0f1 | grep PTP # find the proper ptp device id
PTP Hardware Clock: 3
$ ./testptp -d /dev/ptp3 -T 3333333 # in sec
set time okay
$ ./testptp -d /dev/ptp3 -g
clock time: 3333336.759303339 or Sun Feb  8 08:55:36 1970
$ ./testptp -d /dev/ptp3 -k 1
system and phc clock time offset request okay
system time: 1589581164.437482989
phc    time: 1589581201.437483653
system time: 1589581164.437484167
system/phc clock time offset is -37000000075 ns # 37s is the difference between UTC and International Atomic Time (TAI)
system     clock time delay  is 1178 ns
```

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
