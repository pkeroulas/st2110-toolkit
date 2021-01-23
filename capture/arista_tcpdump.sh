#!/bin/bash
#
# This script captures port traffic on remote Arista switch and shows
# packets on local wireshark in realtime.
#
# Steps:
# - login through ssh
# - init a monitor session
# - mirrors targeted port to cpu interface
# - launch tcpdump in bash
# - launch local wireshark and read from stdin
#
# Limitations:
# - tested on 7020
# - not to be used for high bitrate port

usage(){
    echo "Usage:
    $0 -r <user>@<remote_ip> -p <switch_port> [ filter expr ]
    " >&2
}

while getopts ":r:p:" o; do
    case "${o}" in
        r)
            switch=${OPTARG}
            ;;
        p)
            port=${OPTARG}
            ;;
        *)
            echo  "unsupported option ${o}"
            usage
            exit 1
            ;;
    esac
done

shift $((OPTIND-1))

if [ -z "$switch" -o -z "$port" ]; then
    echo "Missing argument"
    usage
    exit 1
fi

filter=$@
session=scripted

ssh -T $switch "enable
conf
no monitor session $session
monitor session $session source Et$port
monitor session $session destination Cpu
bash tcpdump -i mirror0 -U -s0 -w - $filter" | wireshark -k -i -
