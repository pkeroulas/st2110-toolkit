#!/bin/bash

usage(){
    echo "
'rtcpdump' starts 'tcpdump' on a remote host (Linux or Arista switch),
opens 'wireshark' locally and pipe them together to display the distant
network packets in a GUI, in realtime.

This solution makes the troubleshoot of (lightweigth) network protocols
faster and more confortable, without being physically connected to the
spotted network segment.

Usage:
    $0 -r <user>@<remote_ip> -p <password|password_file> -i <remote_interface> [-c <packet_count>] [-v] ['filter_expression']

    -r ssh path; can be an alias in your local ssh config
    -p password used if you have sshpass installed, can be a password file
    -i remote interface name. On a switch, it can either be simple '10'
       or a part of a quad-port '10/2'
    -c limit of captured packets (default $pkt_count as safety for network)
    -v verbose
    -a Arista ACL filter mode <filter_expression> must be the ACL rule (Rx only)
       filter_expression is passed to remote tcpdump or ACL

Examples:
    - PTP on Arista switch port:
        $0 -r user@server -p pass -i Et10/1 'dst port 319 or dst port 320'
    - IGMP using ACL mode, with password file provided and verbose mode:
        $0 -r user@server -p ~/passwordfile.txt -i Et10/1 -v -a 'permit igmp any any'
    - LLDP:
        $0 -r user@server -p pass -i Et10/1 'ether proto 0x88CC'
    - HTTP between a Arista sw (on the management interface) and a specific host:
        $0 -r user@server -p pass -i Ma1 'port 80 and host XXX.XXX.XXX.XXX'
    - DHCP/bootp on a Linux host for a given MAC:
        $0 -r user@server -p pass -i ens192 'ether host XX:XX:XX:XX:XX:XX and \(port 67 or port 68\)'
    - VLAN-tagged http packets
        $0 -r user@server -p pass -i ens192  '-e \(vlan 1434 and port 80\)'

Script execution steps:
    - login to remote through ssh
    - detect if remote is normal linux host or Arista switch
    - if Arista, init a monitor session that mirrors targeted port to
    cpu interface
    - launch tcpdump in remote bash and output to stdout (raw)
    - launch local wireshark and read from stdin
    - clean up monitor session on wireshark exit

Tested:
    - workstations: Linux, Windows (WSL installed)
    - Arista switches (EOS-4.24.2.1F): DCS-7280CR2A-30,
      DCS-7280SR2-48YC6, DCS-7280TR-48C6, DCS-7280CR3K-32D4,
      DCS-7020TR-48, CCS-720XP-48Y6. Others like CCS-720XP-48ZC2 are not
      supported since 'Monitor session' is limited

Limitations:
    - capturing a high bitrate port isn't a good idea given the additional
      load transfer over the network. This is why the capture is limited
      to 10000 pkts by default. Additionally, a monitor session in a Arista
      switch consists in mirroring the traffic to the Cpu through a 10Mbps
      link. As a result, some packets may be lost, even when a filter is
      given to tcpdump.
    - note that 'StrictHostKeyChecking=no' option is used for ssh, at
      you own risks
" 1>&2
}

function title() {
    printf  "\e[1;34m====================================================\e[m\n" "$1"
    printf  "\e[1;34m%s\e[m\n" "$1"
}

function warning() {
    printf  "\e[1;33m%s\e[m\n" "$1"
}

function error() {
    printf  "\e[1;31m%s\e[m\n" "$1"
}
##################################################################
# CONST

pkt_count=10000
session=RTCPDUMP
filter_mode=tcpdump

##################################################################
# PARSE ARGS

while getopts ":r:p:i:c:va" o; do
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
        a)
            filter_mode=acl
            ;;
        v)
            set -x
            ;;
        *)
            error  "unsupported option ${o}"
            usage
            exit 1
            ;;
    esac
done

shift $((OPTIND-1))

if [ -z "$remote" -o -z "$iface" ]; then
    error "Missing argument"
    usage
    exit 1
fi

filter=$@
ssh_cmd="ssh -T -o StrictHostKeyChecking=no $remote "

##################################################################
# CHECKS

title "RTCPDUMP"

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
    error "$wireshark not found"
    exit 1
fi

if ! which ssh >/dev/null; then
    error "ssh client not found"
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
    warning "
sshpass not installed. It is going to be painful to enter the ssh
password at multiple times. Do you still want to proceed? [y/n]"
    read no
    if [ $no = "n" ]; then
        exit 0
    fi
fi

##################################################################
# Remote detection = regular Linux (easy)

if $ssh_cmd "ls" > /dev/null; then
    echo "Remote: Linux host"
    echo "Interfaces."
    ifaces=$($ssh_cmd "ls /sys/class/net")
    if echo $ifaces | grep  -v -q $iface; then
        echo $iface not found
        exit 1
    fi
    title "Capture $cpu_iface."
    warning ">>>>>>>>>>> Press CTRL+C to interrupt. <<<<<<<<<<<<<"
    $ssh_cmd "tcpdump -i $iface -c $pkt_count -U -s0 -w - $filter" | "$wireshark" -k -i -
    exit 0
fi

##################################################################
# Remote detection = Arista

echo "Remote: Arista switch"

title "Interface: $iface"
echo "lldp:"
if ! $ssh_cmd "show lldp neighbors $iface"; then
    echo "Issue with ssh connection? Exit."
    exit 1
fi

echo "stats:"
port_stat=$($ssh_cmd "show interfaces $iface")
echo "$port_stat"
if echo $port_stat | grep -q -v "is up"; then
    error "Port $iface is wrong or down, exit."
    exit 1
fi

acl_monitor_option=""
if [ $filter_mode = "acl" ]; then
    title "Create a IP access list: $filter"
    $ssh_cmd "enable
conf
ip access-list $session
$filter
"
    # need a short break for Cpu iface allocation
    $ssh_cmd "enable
show ip access-list $session
"
    filter=""
    acl_monitor_option="rx ip access-group $session"
fi

title "Create a monitor session:"
$ssh_cmd "enable
conf
monitor session $session source $iface $acl_monitor_option
monitor session $session destination Cpu"
sleep 1 # need a short break for Cpu iface allocation
sessions=$($ssh_cmd "enable
show monitor session")
echo "$sessions" | grep -v -e '^$' | grep -v "\-\-\-\-\-\-\-"
cpu_iface=$(echo "$sessions" | grep $session -A 14 | grep Cpu | sed 's/.*(\(.*\))/\1/')

if [ -z $cpu_iface ]; then
    echo "Couldn't find cpu interface. Exit."
    exit -1
fi

title "Capture $cpu_iface by Cpu."
warning ">>>>>>>>>>> Press CTRL+C to interrupt. <<<<<<<<<<<<<"

trap 'echo Interrupted.' SIGINT # catch Ctrl-C to exit Arista bash properly

$ssh_cmd "enable
conf
bash tcpdump -i $cpu_iface -c $pkt_count -U -s0 -w - $filter" | "$wireshark" -k -i -

title "Cleanup."
$ssh_cmd "enable
conf
no ip access-list $session
no monitor session $session
show monitor session
bash pidof tcpdump > /dev/null && killall tcpdump
" | grep -v -e '^$'
echo "Exit."
