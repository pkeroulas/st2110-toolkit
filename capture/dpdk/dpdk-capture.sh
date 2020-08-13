#!/bin/bash

usage(){
    echo "$0 interprets tcpdump-like parameters and passes them to
    dpdk utilties, i.e. tespmd and dpdk-pdump
Usage:
    $0 -i interface -w file.pcap [-G <secondes>] [-v] [ filter expr ]
" >&2
}

timeout=2
verbose=0
dual_port=0
testpmd_log=/tmp/dpdk-testpmd.log

dpdk_log(){
    echo "dpdk-capture: $@"
}

dpdk_log "Parse args: ------------------------------------------ "

#  typical cmdline to be translated:
#  $ tcpdump -i interfaceName --time-stamp-precision=nano \
#   -j adapter_unsynced\--snapshot-length=N -v -w pcap -G 2 -W 1 \
#   dst 192.168.1.1 or dst 192.168.1.2
while getopts ":i:w:G:W:v" o; do
    case "${o}" in
        i | interface)
            iface=${OPTARG}
            port=$(echo $iface | sed 's/.*\(.\)/\1/')
            ;;
        j)
            ;;
        #-)
        #    case ${OPTARG} in
        #        time-stamp-precision*)
        #            ;;
        #        snapshot-length*)
        #            ;;
        #    esac
        #    ;;
        w)
            pcap=${OPTARG}
            tmp=/run/$(basename $pcap)
            ;;
        G)
            timeout=${OPTARG}
            ;;
        W)
            #ignore file number
            ;;
        v)
            verbose=1
            set -x
            ;;
            #TODO dual-port
        *)
            dpdk_log  "unsupported option ${o}"
            ;;
    esac
done
shift $((OPTIND-1))

if [ -z $iface -o -z $pcap ]; then
    dpdk_log "Missing argument"
    exit 1
fi

filter=$@
IPs=$(echo $filter | sed 's/dst//g; s/or//g' | tr -s ' ' '\n')

dpdk_log "iface: $iface
pcap: $pcap
tmp: $tmp
filter: $filter
timeout: $timeout"

dpdk_log "Checking interface: $iface ------------------------------------------ "

if [ ! -d /sys/class/net/$iface ]; then
	dpdk_log "$iface doesn\'t exist, exit."
	exit 1
fi
if [ $(cat /sys/class/net/$iface/operstate) != "up" ]; then
	dpdk_log "$iface is not up, exit."
	exit 1
fi

if [ ! -z "$filter" ]; then
    dpdk_log "Joining mcast: $IPs ------------------------------------------ "

    if ! smcroutectl show > /dev/null; then
        smcrouted
    fi

    for ip in $IPs; do
        smcroutectl join $iface $ip
        if ! netstat -ng | grep -q "$iface.*$ip"; then
            dpdk_log "Can\'t joint $ip"
        fi
    done

    if [ $verbose -eq 1 ]; then
        netstat -ng | grep $iface
    fi
else
    dpdk_log "No filter"
fi

# dpdk
dpdk_log "Capturing------------------------------------------"

if [ $verbose -eq 1 ]; then
    dpdk_log "Devices"
    dpdk-devbind --status | grep "if=$iface"
    #0000:01:00.0 'MT27800 Family [ConnectX-5] 1017' if=enp1s0f0 drv=mlx5_core unused= *Active*
fi

dpdk_log "Start PMD"
pci=$(dpdk-devbind --status | grep "ConnectX" | \
    cut -d ' ' -f1 | sed 's/\(.*\)/ -w \1 /' | tr -d '\n')
# create a detached session to run PMD server
screen -dmS testpmd -L -Logfile $testpmd_log \
    testpmd $pci -n4 -- --enable-rx-timestamp --mbcache=512

sleep 3

# TODO: compile and pass a filter

pkt_rx_start=$(ethtool -S $iface | grep rx_packets: | sed  's/.*: \(.*\)/\1/')
pkt_drop_start=$(ethtool -S $iface | grep rx_out_of_buffer: | sed  's/.*: \(.*\)/\1/')

dpdk_log "Start pdump port:$port"
if [ $dual_port -eq 1 ]; then
    args="--multi --pdump port=0,queue=*,rx-dev=$tmp.0 --pdump \"port=1,queue=*,rx-dev=$tmp.1\""
    # maybe -c 2 needed
else
    args="--pdump port=$port,queue=*,rx-dev=$tmp.$port"
fi
dpdk-pdump -- $args 2>&1 &

sleep $timeout

dpdk_log "Stop testpmd / pdump -------------------------------------"
# send a SGINT after after timeout
killall -s 2 dpdk-pdump

# send carriage return to stop testpmd
screen -S testpmd -X stuff "
"
if [ $verbose -eq 1 ]; then
    cat $testpmd_log
fi
rm $testpmd_log

if [ ! -z "$filter" ]; then
    dpdk_log "Leaving mcast ------------------------------------------"

    for ip in $IPs; do
        smcroutectl leave $iface $ip
    done
fi

if [ $verbose -eq 1 ]; then
    dpdk_log "pcapinfo port $port"
    capinfos $tmp.$port
fi

pkt_rx_end=$(ethtool -S $iface | grep rx_packets: | sed  's/.*: \(.*\)/\1/')
pkt_drop_end=$(ethtool -S $iface | grep rx_out_of_buffer: | sed  's/.*: \(.*\)/\1/')
dpdk_log "rx: $(echo "$pkt_rx_end - $pkt_rx_start" | bc)"
dpdk_log "drop: $(echo "$pkt_drop_end - $pkt_drop_start" | bc)"

mv $pcap.$port $pcap
#TODO if dual port merge
#TODO files after a period

