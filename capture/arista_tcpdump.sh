#!/bin/bash
#
# This script captures port traffic on remote Arista switch and shows
# packets on local wireshark in realtime.
#
# Steps:
# - login to switch through ssh
# - init a monitor session that mirrors targeted port to cpu interface
# - launch tcpdump in remote bash and output to stdout
# - launch local wireshark and read from stdin
#
# Limitations:
# - tested on (DCS-7280CR2A-30, EOS-4.24.2.1F)
# - high bitrate port will saturate the switch cpu and packet transfer
# to localhost. Typical application is to monitor control signals rather
# than media traffic.

usage(){
    echo "Usage:
    $0 -r <user>@<remote_ip> -w <password> -p <switch_port> [-v] ['filter expression']
notes:
    -r can refer to connexion in your local ssh config
    -w is used if you have sshpass installed
    -p can either be simple '10' or a part of a quad-port '10/2'
    filter express is passed to remote tcpdump
exple:
    $0 -r admin@$IP [-w admin] -p 10/1 'dst port 319'
    " >&2
}

while getopts ":r:w:p:v:" o; do
    case "${o}" in
        r)
            switch=${OPTARG}
            ;;
        p)
            port=${OPTARG}
            ;;
        w)
            pass=${OPTARG}
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

if [ -z "$switch" -o -z "$port" ]; then
    echo "Missing argument"
    usage
    exit 1
fi

filter=$@
session=scripted
ssh_cmd="ssh -T $switch "

if which sshpass >/dev/null; then
    if [ ! -z "$pass" ]; then
        echo "Poke......."
        ssh_cmd="sshpass -p $pass $ssh_cmd"
        $ssh_cmd "enable
conf
show running-conf" | head -10
    fi
else
    echo "sshpass not installed. Enter switch password."
fi

echo "Capture......."
$ssh_cmd "enable
conf
monitor session $session source Et$port
monitor session $session destination Cpu
bash tcpdump -i mirror0 -U -s0 -w - $filter" | wireshark -k -i -

echo "Cleanup......."
$ssh_cmd "enable
conf
no monitor session $session
"

echo "Exit.........."
