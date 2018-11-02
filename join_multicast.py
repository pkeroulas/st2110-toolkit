#! /usr/bin/env python

import sys
import time
import socket

BUFSIZE = 1024

def usage():
    print("""
join_multicast.py - helper script to join a multicast group
Usage:
\tjoin_multicast.py <multicast_group> <interface_ip|interface_name> [multicast port]
\tmulticast_group - IP address of the multicast group to be joined
\tinterface_ip    - IP address of the interface whishing to join the multicast group
\tinterface_name  - name of the interfacde whishing to join the multicast group
\tmulticast_port  - port to bind to to listen to multicast traffic
""")
    sys.exit(0)

def get_interface_ip(interface):
    try:
        socket.inet_aton(interface)
        return interface
    except socket.error:
        try:
            import netifaces

            interface_ip = netifaces.ifaddresses(interface)[netifaces.AF_INET][0]['addr']
            return interface_ip
        except ModuleNotFoundError:
            print("'netifaces' is not installed. Second argument must be an IP address")
            print("To support interface name, the module must be present.")

def main():
    if len(sys.argv) < 3:
        usage()

    multicast_group = sys.argv[1]
    interface = sys.argv[2]
    interface_ip = get_interface_ip(interface)

    multicast_port = None
    if len(sys.argv) >= 4:
        multicast_port = sys.argv[3]
    join_multicast(multicast_group,  interface_ip, multicast_port)

def join_multicast(multicast_group, interface_ip, multicast_port):
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

    if multicast_port:
        multicast_port = int(multicast_port)
        s.bind(("", multicast_port))

    try:
        mreq = socket.inet_aton(multicast_group) + socket.inet_aton(interface_ip)
        s.setsockopt(socket.IPPROTO_IP, socket.IP_ADD_MEMBERSHIP, mreq)
        s.settimeout(1)
    except socket.error:
        print("Couldn't join multicast group {}.\n".format(multicast_group))
        return

    print("Joined multicast group {}. Press Ctrl-C to exit\n".format(multicast_group))
    counter = 0
    before_time = time.time()
    try:
        while True:
            try:
                if multicast_port:
                    data = s.recv(BUFSIZE)
                    counter += len(data)
            except socket.timeout:
                pass
            current_time = time.time()
            if current_time - before_time > 1:
                print("Received {}/s\r".format(pretty_counter(counter)))
                counter = 0
                before_time = current_time
                sys.stdout.flush()
    except KeyboardInterrupt:
        s.setsockopt(socket.IPPROTO_IP, socket.IP_DROP_MEMBERSHIP, mreq)
        s.close()
        print("Bye.")

def pretty_counter(value):
    unit = ""

    value *= 8
    value = float(value)
    if value > 1000 * 1000 * 1000:
        value /= 1000 * 1000 * 1000
        unit = "G"
    elif value > 1000 * 1000:
        value /= 1000 * 1000
        unit = "M"
    elif value > 1000:
        value /= 1000
        unit = "K"

    return "{}{}b".format(round(value, 3), unit)


try:
    main()
except KeyboardInterrupt:
    print("Bye.")
