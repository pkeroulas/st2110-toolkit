# Capture

## NIC

The first thing to do on system startup is to setup the network
interface controller (NIC).

```sh
$ sudo ./nic_setup.sh eth0
[...]
```

## Stream description: SDP file

ST2110 senders, like Embrionix encap, should provide an SDP file to
describe every produced essences, i.e. RTP streams.

A python script grabs SDP from Embrionix encapsulator given its unicast
address. The result is a SDP file which contains the selected flows
provided by the source. See [flow description.](../doc/embrionix.md) for
more details.

```sh
$ ./get_sdp.py <sender_IP> <flows>
$ ./get_sdp.py 192.168.1.176 0 2 18
[...]
------------------------------------------------------------------------
SDP written to emb_encap_176.sdp
```

[Embrinonix SDP example.](../doc/sdp.sample)

When using some applications like ffmpeg, a wrong interface to perform
the IGMP join to multicast group. Setup the IP routing table fixes.
Firewall rules may also be needed to unblock the traffic from the NIC to
the userspace socket interface. This is all done by this script:

```sh
$ ./network_setup.sh sdp.file
[...]
```

## Execute

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
$ ./network_setup.sh file.sdp
[...]
```

You can validate that the multicast IGMP group is joined and that data
is received thanks to the socket reader:

```sh
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
