#!/bin/bash

# const
CONF_FILE='capture.conf'
CAPTURE=tmp.pcap
MAX_COUNT=100000
SCRIPT=$(basename $0)
DURATION=2

help() {
	echo "
$SCRIPT joins multicast groups and captures the incoming traffic in
file: <date>_<hostname>_<source_ip>.pcap

Usage:
    $SCRIPT # source params from capture.conf
    $SCRIPT <network_interface> <mgroup> <port> <duration(sec)>"
}

# read param from either argument or conf file
if [ $# -eq 3 ]; then
    IFACE=$1
    MCAST_IPs=$2
    DURATION=$3
elif [ -f $CONF_FILE ]; then
    source $CONF_FILE
    if [ -z $IFACE -o -z $MCAST_IPs ]; then
        echo "Missing variable in $CONF_FILE"
        exit 1
    fi
else
    help
    exit 1
fi

echo "------------------------------------------
Mcast IPs:
$MCAST_IPs" | tr ' ' '\n'

echo "------------------------------------------
Joining"

for m in $MCAST_IPs; do
    smcroute -j $IFACE $m
done

echo "------------------------------------------
Capturing"

tcpdump -vvv -j adapter -i $IFACE -n "multicast" -c $MAX_COUNT -w $CAPTURE &
tcpdump_pid=$!

for i in $(seq $DURATION); do
    echo "$i sec ..."
    sleep 1
done

kill -0 $tcpdump_pid 2>/dev/null && kill $tcpdump_pid

echo "------------------------------------------
Leaving"

for m in $MCAST_IPs; do
    smcroute -l $IFACE $m
done

if [ ! -f $CAPTURE ]; then
    echo "No capture file."
    exit 1
fi

FILENAME="$(date +%F_%T)_$(hostname)_$(echo $SOURCE_IP | tr . _).pcap"
mv $CAPTURE $FILENAME

echo "------------------------------------------
Output file:
$(du -h $FILENAME)"
