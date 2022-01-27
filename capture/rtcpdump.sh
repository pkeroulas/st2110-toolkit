#!/bin/bash

usage(){
    echo "
This script starts 'tcpdump' on a remote host and shows packets on
local wireshark in realtime. The remote can either be a regular Linux host
or a Arista switch.

Usage:
    $0 -r <user>@<remote_ip> -p <password> -i <remote_interface> \
        [-c <packet_count>] [-v] ['filter_expression']

Params:
    -r ssh path; can be an alias in your local ssh config
    -p password used if you have sshpass installed, can be a password file
    -i remote interface name. On a switch, it can either be simple '10'
    or a part of a quad-port '10/2'
    -c limit of captured packets (default $pkt_count as safety for network)
    -v verbose
    filter_expression is passed to remote tcpdump

Examples:
    - PTP on Arista switch port:
        $0 -r user@server -p pass -i Et10/1 'dst port 319 or dst port 320'
    - LLDP:
        $0 -r user@server -p pass -i Et10/1 'ether proto 0x88CC'
    - HTTP on Arista management interface:
        $0 -r user@server -p pass -i Ma1 'port 80'
    - DHCP/bootp on a Linux host for a given MAC:
        $0 -r user@server -p pass -i ens192 'ether \
            host XX:XX:XX:XX:XX:XX and \(port 67 or port 68\)'

Script steps:
    - login to remote through ssh
    - detect if remote is normal linux host or Arista switch
    - if Arista, init a monitor session that mirrors targeted port to
    cpu interface
    - launch tcpdump in remote bash and output to stdout (raw)
    - launch local wireshark and read from stdin
    - clean up monitor session on wireshark exited

Others:
    - tested workstation:
        * Linux workstation
        * Windows workstation with WSL installed
    - tested remote: Arista switches (EOS-4.24.2.1F):
        * DCS-7280CR2A-30
        * DCS-7280SR2-48YC6
        * DCS-7020TR-48
    - capturing a high bitrate port isn't good idea given the additional
    data transfer over the network (plus, on Arista switch, the traffic is
    mirrored to Cpu which might be overflowed). This is why the capture is
    limited to 10000 pkts by default.
    - note that 'StrictHostKeyChecking=no' option is used for ssh, at
    you own risks
" 1>&2
}

##################################################################
# CONST

pkt_count=10000
session=scripted

##################################################################
# PARSE ARGS

while getopts ":r:p:i:c:v" o; do
    case "${o}" in
        r)
            remote=${OPTARG}
            ;;
        i)
            iface=${OPTARG}
            ;;
        p)
            if [ -f ${OPTARG} ]; then
                passfile=${OPTARG}
            else
                password=${OPTARG}
            fi
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

if [ -z "$remote" -o -z "$iface" ]; then
    echo "Missing argument"
    usage
    exit 1
fi

filter=$@
ssh_cmd="ssh -T -o StrictHostKeyChecking=no $remote "

##################################################################
# CHECKS

if mount | grep -q  "type 9p"; then
    echo "Host: WSL"
    # FIXME: wireshark complains about IOR.txt wrong permission but the
    # capture works fine
    wireshark="/mnt/c/Progra~1/Wireshark/Wireshark.exe"
else
    echo "Host: Linux"
    wireshark=$(which wireshark)
fi

if [ ! -f  "$wireshark" ]; then
    echo "$wireshark not found"
    exit 1
fi

if ! which ssh >/dev/null; then
    echo "ssh client not found"
    exit 1
fi

if which sshpass >/dev/null; then
    if [ ! -z "$passfile" ]; then
        ssh_cmd="sshpass -f $passfile $ssh_cmd"
    elif [ ! -z "$password" ]; then
        ssh_cmd="sshpass -p $password $ssh_cmd"
    else #from stdin
        ssh_cmd="sshpass $ssh_cmd"
    fi
else
    echo "
sshpass not installed. It is going to be painful to enter the ssh
password at multiple times. Do you still want to proceed? [y/n]"
    read no
    if [ $no = "n" ]; then
        exit 0
    fi
fi

##################################################################
# GO

# Regular Linux remote: easy
if $ssh_cmd "ls" > /dev/null; then
    echo "Remote: Linux host"
    echo "------------------------"
    echo "Interfaces."
    ifaces=$($ssh_cmd "ls /sys/class/net")
    if echo $ifaces | grep  -v -q $iface; then
        echo $iface not found
        exit 1
    fi
    echo "Capture......."
    $ssh_cmd "tcpdump -i $iface -c $pkt_count -U -s0 -w - $filter" | "$wireshark" -k -i -
    exit 0
fi

echo "Remote: Arista switch"
echo "------------------------"
echo "Port: $iface"
echo "lldp:"
$ssh_cmd "show lldp neighb | grep $iface"
echo "stats:"
echo "Create a monitor session."
$ssh_cmd "enable
conf
monitor session $session source $iface
monitor session $session destination Cpu
show interfaces $iface"

echo "------------------------"
# need a short break for Cpu iface allocation
sessions=$($ssh_cmd "enable
conf
show monitor session")
echo "Monitor session."
echo "$sessions"
cpu_iface=$(echo "$sessions" | grep $session -A 10 | grep Cpu | sed 's/.*(\(.*\))/\1/')

trap 'echo Interruption.' 2 # catch SIGINT (Ctrl-C) to exit Arista bash properly

echo "------------------------"
echo "Capture on Cpu($cpu_iface) ......."
$ssh_cmd "enable
conf
bash tcpdump -i $cpu_iface -c $pkt_count -U -s0 -w - $filter" | "$wireshark" -k -i -

echo "------------------------"
echo "Cleanup."
$ssh_cmd "enable
conf
no monitor session $session
show monitor session
"

echo "Exit."
