#!/bin/bash
#
# This script captures port traffic on remote host and shows packets on
# local wireshark in realtime. Host can either be a regular Linux host
# or a Arista switch.
#
# TLDR: tcpdump (remote) | wireshark (local)
#
# Steps:
# - login to remote through ssh
# - detect if remote is normal linux host or Arista switch
# - if Arista, init a monitor session that mirrors targeted port to cpu interface
# - launch tcpdump in remote bash and output to stdout
# - launch local wireshark and read from stdin
#
# - tested on Arista switches (DCS-7280CR2A-30, EOS-4.24.2.1F)
# - capturing a high bitrate port isn't good idea given the additional
# data transfer over the network (plus, on Arista switch, the traffic is
# mirrored to Cpu which might be overflowed). This is why the capture is
# limited to 10000 pkts by default.

remote="normal linux"
pkt_count=10000

usage(){
    echo "Usage:
    $0 -r <user>@<remote_ip> -p <password> -i <remote_interface> [-c <packet_count>] [-v] ['filter_expression']
notes:
    -r can refer to connexion in your local ssh config
    -p password used if you have sshpass installed
    -i remote interface name. On a switch, it can either be simple '10' or a part of a quad-port '10/2'
    -c limit of captured packets (default $pkt_count as safety for network)
    -v verbose
    filter_expression is passed to remote tcpdump
exple:
    monitor PTP on Arita switch:
    $0 -r user@$IP -p passwd -i 10/1 'dst port 319 or dst port 320'
    monitor DHCP on Linux host:
    $0 -r user@$IP -c 50 -i eth0 'port 67 or port 68'
    " >&2
}

while getopts ":r:p:i:c:v:" o; do
    case "${o}" in
        r)
            switch=${OPTARG}
            ;;
        i)
            iface=${OPTARG}
            ;;
        p)
            pass=${OPTARG}
            ;;
        c)
            pkt_count=${OPTARG}
            ;;
        v)
            set -x
            ;;
        *)
            echo  "unsupported option ${o}"
            usage
            exit 1
            ;;
    esac
done

shift $((OPTIND-1))

if [ -z "$switch" -o -z "$iface" ]; then
    echo "Missing argument"
    usage
    exit 1
fi

filter=$@
session=scripted
ssh_cmd="ssh -T $switch "
if which sshpass >/dev/null; then
    if [ ! -z "$pass" ]; then
        ssh_cmd="sshpass -p $pass $ssh_cmd"
    fi
else
    echo "sshpass not installed. Enter switch password."
fi

echo "Poke remote."
if ! $ssh_cmd "ls" > /dev/null; then
    remote="arista"
fi
echo "Mode : $remote"

if [ $remote = "arista" ]; then
    echo "Create a monitor session."
    $ssh_cmd "enable
    conf
    monitor session $session source Et$iface
    monitor session $session destination Cpu
    show interfaces ethernet $iface"

    # need a short break for Cpu iface allocation
    sessions=$($ssh_cmd "enable
    conf
    show monitor session")
    echo "$sessions"
    cpu_iface=$(echo "$sessions" | grep $session -A 10 | grep Cpu | sed 's/.*(\(.*\))/\1/')

    trap 'echo Interruption.' 2 # catch SIGINT (Ctrl-C) to exit Arista bash properly

    echo "Capture on Cpu($cpu_iface) ......."
    $ssh_cmd "enable
    conf
    bash tcpdump -i $cpu_iface -c $pkt_count -U -s0 -w - $filter" | wireshark -k -i -

    echo "Cleanup."
    $ssh_cmd "enable
    conf
    no monitor session $session
    "
else
    echo "Interfaces."
    $ssh_cmd "ls /sys/class/net"
    #TODO get interface automatically?
    echo "Capture......."
    $ssh_cmd "tcpdump -i $iface -c $pkt_count -U -s0 -w - $filter" | wireshark -k -i -
fi

echo "Exit."
