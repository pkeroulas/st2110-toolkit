#!/bin/bash

port=0
verbose=0
dual_port=0
pcap=/tmp/dpdk.pcap
timeout=2
testpmd_log=/tmp/dpdk-testpmd.log

set -x

dpdk_log()
{
    echo "dpdk-capture: $@"
}

while getopts ":i:w:t:v" o; do
    case "${o}" in
        i | interface)
            iface=${OPTARG}
            port=$(echo $iface | sed 's/.*\(.\)/\1/')
            ;;
        w)
            pcap=${OPTARG}
            ;;
        t)
            timeout=${OPTARG}
            ;;
        v)
            verbose=1
            ;;
            #TODO dual-port
        *)
            dpdk_log  "unsupported option"
            ;;
    esac
done
shift $((OPTIND-1))

if [ -z $iface ]; then
    dpdk_log "Missing argument"
    exit 1
fi

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
    testpmd $pci -n4 -- --enable-rx-timestamp

sleep 3

# TODO: compile and pass a filter

dpdk_log "Start pdump port:$port"
if [ $dual_port -eq 1 ]; then
    args="--multi --pdump port=0,queue=*,rx-dev=$pcap.0 --pdump \"port=1,queue=*,rx-dev=$pcap.1\""
    # maybe -c 2 needed
else
    args="--pdump port=$port,queue=*,rx-dev=$pcap.$port"
fi
dpdk-pdump -- $args 2>&1 &

sleep $timeout

dpdk_log "Stop pdump"
# send a SGINT after after timeout
killall -s 2 dpdk-pdump

cat $testpmd_log
dpdk_log "Stop PMD"
# send carriage return to stop testpmd
screen -S testpmd -X stuff "
"

if [ $verbose -eq 1 ]; then
    dpdk_log "pcapinfo port $port"
    capinfos $pcap.$port
fi

rm -f $pcap
ln -s $pcap.$port $pcap
#TODO if dual port merge
#TODO files after a period
