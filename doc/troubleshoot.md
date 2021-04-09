# Troubleshoot

When a new system is up, you should validate a few steps before
using a media application like EBU-LIST or ffmpeg:

* IGMP works
* the NIC sees the stream
* the application sees the stream

## IGMP: is it possible to join a multicast stream?

You can validate that the multicast IGMP group is joined and that data
is received thanks to the socket reader:

```sh
$ cd capture/
$ gcc -o socket_reader -std=c99 socket_reader.c
$ ./socket_reader -g <multicast-address> -p <udp-port> -i <local-IP-of-media-interface>
```

Validate that the multicast group is joined through the correct
interface:

```sh
netstat -ng | grep <multicast-group>
```


When capturing traffic (as opposed to transcoding), if `smcroute` returns this error, restart the daemon:

```
Daemon error: Join multicast group, unknown interface eth0
$ sudo /etc/init.d/smcroute restart
```

Measure the UDP packet drops:

```sh
netstat -s -u
```

## NIC: is the stream present?

`tcpdump` is our friend but it can't guess on which interface to throw the IGMP join request.
You need to create a static route before:

```sh
ip route add <multicast-group> via <gateway-ip> dev <media-interface>
tcpdump -i <media-interface>
```

Verify that multicast is joined using the correct interface with `netstat -ng`.

## App: is the stream visible?

Re-use the `socket_reader`:

```sh
$ ./socket_reader -g <multicast-address> -p <udp-port> -i <local-IP-of-media-interface>
Detected stream with payload type 96
Missed or missing RTP marker
^Creceived SIGINT
received: 857470
dropped: 14564
1.67 % drop
```

If the stream can be seen by `tcpdump` but not by an app like
`socket_reader`, it can either be blocked by the firewall or the stream
source verification. Let's take the example of Centos for which security
is tighter than Debian.

First the firewall must let the UDP port in:

```sh
firewall-cmd --zone=public --add-port=20000/udp --permanent
firewall-cmd --reload
```

Then, the source of the stream must be verified by either create a
static route:

```sh
ip route add <multicast-source-ip> via <gateway-ip> dev <media-interface>
```

OR disable the reverse path filter:

```sh
sysctl -w net.ipv4.conf.all.rp_filter=0
sysctl -w net.ipv4.conf.<media-interface>.rp_filter=0
```

Create a new file in `/usr/lib/sysctl.d/` for persistency.
