#!/bin/bash

pcap_file=/tmp/dpdk.pcap
timeout=3
port=0
verbose=1
dual_port=0

if [ $verbose -eq 1 ]; then
    echo "Devices:::::::::::::::"
    dpdk-devbind --status | grep ConnectX
    #0000:01:00.0 'MT27800 Family [ConnectX-5] 1017' if=enp1s0f0 drv=mlx5_core unused= *Active*
fi

echo "Start PMD:::::::::::::::"
# create a detached session to run PMD server
pci=$(dpdk-devbind --status | grep ConnectX | \
    cut -d ' ' -f1 | sed 's/\(.*\)/ -w \1 /' | tr -d '\n')
screen -dmS testpmd -L -Logfile /tmp/testpmd.log \
    testpmd $pci -n4 -- --enable-rx-timestamp

sleep 3

# TODO: compile and pass a filter

echo "Start pdump::::::::::::::: port:$port"
args="--pdump \"port=0,queue=*,rx-dev=$pcap_file.0\""
if [ $dual_port -eq 1 ]; then
    args=$args" --pdump \"port=1,queue=*,rx-dev=$pcap_file.1\""
fi
dpdk-pdump -c $port -- --multi $args  2>&1 > /tmp/pdump.log &

sleep $timeout

echo "Stop pdump::::::::::::::::"
# send a SGINT after after timeout
killall -s 2 dpdk-pdump

echo "Stop PMD::::::::::::::::"
# send carriage return to stop testpmd
screen -S testpmd -X stuff "
"

if [ $verbose -eq 1 ]; then
    for port in 0 1; do
        echo "Cap info::::::::::::::: port:$i"
        capinfos $pcap_file.$port
    done
fi
